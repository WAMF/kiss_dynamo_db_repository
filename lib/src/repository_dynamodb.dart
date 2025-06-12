import 'dart:async';

import 'package:collection/collection.dart';
import 'package:document_client/document_client.dart';
import 'package:kiss_repository/kiss_repository.dart';

import 'utils/batch_operations.dart';
import 'utils/dynamodb_identified_object.dart';
import 'utils/object_extraction_helpers.dart';
import 'utils/query_expression_helpers.dart';

class RepositoryDynamoDB<T> extends Repository<T> {
  RepositoryDynamoDB({
    required this.client,
    required this.tableName,
    required this.fromDynamoDB,
    required this.toDynamoDB,
    this.queryBuilder,
  });

  final DocumentClient client;
  final String tableName;
  final T Function(Map<String, dynamic> item) fromDynamoDB;
  final Map<String, dynamic> Function(T object) toDynamoDB;
  final QueryBuilder<Map<String, dynamic>>? queryBuilder;

  @override
  String get path => tableName;

  @override
  Future<T> get(String id) async {
    try {
      final result = await client.get(tableName: tableName, key: {'id': id});

      return fromDynamoDB(result.item);
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException(message: 'Failed to get record: $e');
    }
  }

  @override
  Future<T> add(IdentifiedObject<T> item) async {
    try {
      final data = toDynamoDB(item.object);
      data['id'] = item.id;

      await client.put(
        tableName: tableName,
        item: data,
        conditionExpression: 'attribute_not_exists(id)', // Prevent overwrites
      );

      return fromDynamoDB(data);
    } on ConditionalCheckFailedException {
      throw RepositoryException.alreadyExists(item.id);
    } catch (e) {
      throw RepositoryException(message: 'Failed to add record: $e');
    }
  }

  @override
  Future<T> update(String id, T Function(T current) updater) async {
    try {
      // Get current item
      final currentResult = await client.get(tableName: tableName, key: {'id': id});

      final current = fromDynamoDB(currentResult.item);
      final updated = updater(current);
      final data = toDynamoDB(updated);
      data['id'] = id; // Ensure ID is preserved

      // Update the item
      await client.put(tableName: tableName, item: data);

      return fromDynamoDB(data);
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException(message: 'Failed to update record: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await client.delete(tableName: tableName, key: {'id': id});
      // DynamoDB delete is idempotent - no error for non-existent items
    } catch (e) {
      throw RepositoryException(message: 'Failed to delete record: $e');
    }
  }

  @override
  Future<List<T>> query({Query query = const AllQuery()}) async {
    try {
      if (query is AllQuery) {
        // Simple scan for all items
        final result = await client.scan(tableName: tableName);
        final items = result.items ?? [];
        final objects = items.map((item) => fromDynamoDB(item)).toList();

        // Sort by creation date descending (newest first) to match other repositories
        objects.sort((a, b) {
          // Try to extract creation date from objects
          try {
            final aCreated = extractCreatedDate(a);
            final bCreated = extractCreatedDate(b);
            return bCreated.compareTo(aCreated); // Descending order (newest first)
          } catch (e) {
            // If sorting fails, maintain original order
            return 0;
          }
        });

        return objects;
      } else if (queryBuilder != null) {
        // Use query builder to create scan parameters
        final scanParams = buildExpressionAttributeValues(query);
        if (scanParams == null || scanParams.isEmpty) {
          throw RepositoryException(message: 'Query builder returned empty scan parameters for query: $query');
        }

        // Extract components from the scan parameters map
        final filterExpression = scanParams['filterExpression'] as String?;
        final expressionAttributeNames = buildExpressionAttributeNames(query);
        final expressionAttributeValues = scanParams;

        // Scan with filter expression
        final result = await client.scan(
          tableName: tableName,
          filterExpression: filterExpression,
          expressionAttributeValues: expressionAttributeValues,
          expressionAttributeNames: expressionAttributeNames,
        );

        final items = result.items ?? [];
        final objects = items.map((item) => fromDynamoDB(item)).toList();

        // Sort by creation date descending for consistency with AllQuery
        objects.sort((a, b) {
          try {
            final aCreated = extractCreatedDate(a);
            final bCreated = extractCreatedDate(b);
            return bCreated.compareTo(aCreated);
          } catch (e) {
            return 0;
          }
        });

        return objects;
      } else {
        throw RepositoryException(
          message:
              'Query builder required for custom queries. '
              'Please provide a QueryBuilder<Map<String, dynamic>> in the repository constructor.',
        );
      }
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException(message: 'Failed to query records: $e');
    }
  }

  @override
  Stream<T> stream(String id) {
    final controller = StreamController<T>();
    bool hasEmitted = false;
    T? lastEmittedData;
    Timer? timer;
    int emissionCount = 0;

    void fetchAndEmit() async {
      try {
        final data = await get(id);

        if (!hasEmitted || data != lastEmittedData) {
          hasEmitted = true;
          lastEmittedData = data;
          emissionCount++;

          final dynamic obj = data;
          final name = extractName(obj);
          print('🔄 Stream emission #$emissionCount for $id: name="$name"');
          controller.add(data);
        }
      } catch (e) {
        if (e is RepositoryException && e.message.contains('not found')) {
          if (!hasEmitted) {
            controller.addError(RepositoryException.notFound(id));
          } else {
            controller.close();
          }
        } else {
          controller.addError(e);
        }
      }
    }

    controller.onListen = () {
      print('🎧 Started listening to stream for $id');
      fetchAndEmit();
      timer = Timer.periodic(Duration(milliseconds: 100), (_) => fetchAndEmit());
    };

    controller.onCancel = () {
      print('🛑 Cancelled stream for $id after $emissionCount emissions');
      timer?.cancel();
    };

    return controller.stream;
  }

  @override
  Stream<List<T>> streamQuery({Query query = const AllQuery()}) {
    late StreamController<List<T>> controller;
    Timer? timer;
    List<T>? lastEmittedData;
    int emissionCount = 0;

    controller = StreamController<List<T>>(
      onListen: () async {
        print('🎧 Started listening to query stream');
        try {
          final initialData = await this.query(query: query);
          lastEmittedData = List.from(initialData);
          emissionCount++;
          print('🔄 Query stream emission #$emissionCount: ${initialData.length} items');
          controller.add(initialData);
        } catch (e) {
          controller.addError(e);
        }

        timer = Timer.periodic(Duration(milliseconds: 200), (_) async {
          try {
            final data = await this.query(query: query);
            // Use Dart's built-in list equality - much simpler!
            if (!const ListEquality().equals(lastEmittedData, data)) {
              lastEmittedData = List.from(data);
              emissionCount++;
              print('🔄 Query stream emission #$emissionCount: ${data.length} items');
              controller.add(data);
            }
          } catch (e) {
            controller.addError(e);
          }
        });
      },
      onCancel: () {
        print('🛑 Cancelled query stream after $emissionCount emissions');
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<Iterable<T>> addAll(Iterable<IdentifiedObject<T>> items) async {
    try {
      // DynamoDB doesn't have batch writes in document client, so we'll use individual puts
      // TODO: Optimize with BatchWriteItem when implementing native DynamoDB operations
      final results = <T>[];

      for (final item in items) {
        final result = await add(item);
        results.add(result);
      }

      return results;
    } catch (e) {
      throw RepositoryException(message: 'Batch add operation failed: $e');
    }
  }

  @override
  Future<Iterable<T>> updateAll(Iterable<IdentifiedObject<T>> items) async {
    if (items.isEmpty) return [];

    try {
      final itemsList = items.toList();

      // Step 1: Batch check that ALL items exist (atomic validation)
      await checkItemsExist(client: client, tableName: tableName, ids: itemsList.map((item) => item.id));

      // Step 2: Batch update all items (they all exist now)
      await batchWriteItems<T>(client: client, tableName: tableName, items: itemsList, toDynamoDB: toDynamoDB);

      // Step 3: Return the updated results
      final results = <T>[];
      for (final item in itemsList) {
        final data = toDynamoDB(item.object);
        data['id'] = item.id;
        results.add(fromDynamoDB(data));
      }

      return results;
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException(message: 'Batch update operation failed: $e');
    }
  }

  @override
  Future<void> deleteAll(Iterable<String> ids) async {
    try {
      for (final id in ids) {
        await delete(id);
      }
    } catch (e) {
      throw RepositoryException(message: 'Batch delete operation failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    // Nothing to dispose for DynamoDB client
  }

  @override
  IdentifiedObject<T> autoIdentify(T object, {T Function(T object, String id)? updateObjectWithId}) {
    return DynamoDBIdentifiedObject(object, updateObjectWithId ?? (object, id) => object);
  }

  @override
  Future<T> addAutoIdentified(T object, {T Function(T object, String id)? updateObjectWithId}) async {
    final autoIdentifiedObject = autoIdentify(object, updateObjectWithId: updateObjectWithId);
    return add(autoIdentifiedObject);
  }
}
