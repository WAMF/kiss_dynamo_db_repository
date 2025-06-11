import 'dart:async';

import 'package:document_client/document_client.dart';
import 'package:kiss_repository/kiss_repository.dart';

import 'utils/batch_operations.dart';
import 'utils/dynamodb_identified_object.dart';
import 'utils/type_converter.dart';

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

      if (result.item == null) {
        throw RepositoryException.notFound(id);
      }

      return fromDynamoDB(result.item!);
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

      if (currentResult.item == null) {
        throw RepositoryException.notFound(id);
      }

      final current = fromDynamoDB(currentResult.item!);
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
            final aCreated = _extractCreatedDate(a);
            final bCreated = _extractCreatedDate(b);
            return bCreated.compareTo(aCreated); // Descending order (newest first)
          } catch (e) {
            // If sorting fails, maintain original order
            return 0;
          }
        });

        return objects;
      } else if (queryBuilder != null) {
        // Use query builder to create scan parameters
        final scanParams = queryBuilder!.build(query);
        if (scanParams.isEmpty) {
          throw RepositoryException(message: 'Query builder returned empty scan parameters for query: $query');
        }

        // Extract components from the scan parameters map
        final filterExpression = scanParams['filterExpression'] as String?;
        final expressionAttributeNames = scanParams['expressionAttributeNames'] as Map<String, String>?;
        final expressionAttributeValues = scanParams['expressionAttributeValues'] as Map<String, dynamic>?;

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
            final aCreated = _extractCreatedDate(a);
            final bCreated = _extractCreatedDate(b);
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

  /// Build expression attribute values for DynamoDB filter expressions
  Map<String, dynamic>? _buildExpressionAttributeValues(Query query) {
    // Import the query types
    if (query.runtimeType.toString().contains('QueryByName')) {
      final dynamic queryByName = query;
      return {':namePrefix': queryByName.namePrefix};
    }
    if (query.runtimeType.toString().contains('QueryByPriceGreaterThan')) {
      final dynamic queryByPrice = query;
      return {':priceThreshold': queryByPrice.price};
    }
    if (query.runtimeType.toString().contains('QueryByPriceLessThan')) {
      final dynamic queryByPrice = query;
      return {':priceThreshold': queryByPrice.price};
    }
    if (query.runtimeType.toString().contains('QueryByCreatedAfter')) {
      final dynamic queryByCreated = query;
      return {':dateThreshold': queryByCreated.date.toIso8601String()};
    }
    if (query.runtimeType.toString().contains('QueryByCreatedBefore')) {
      final dynamic queryByCreated = query;
      return {':dateThreshold': queryByCreated.date.toIso8601String()};
    }
    return null;
  }

  /// Build expression attribute names for DynamoDB filter expressions
  Map<String, String>? _buildExpressionAttributeNames(Query query) {
    if (query.runtimeType.toString().contains('QueryByName')) {
      return {'#name': 'name'};
    }
    if (query.runtimeType.toString().contains('QueryByPrice')) {
      return {'#price': 'price'};
    }
    if (query.runtimeType.toString().contains('QueryByCreated')) {
      return {'#created': 'created'};
    }
    return null;
  }

  /// Helper method to extract creation date from objects
  /// Assumes objects have a 'created' field that is a DateTime
  DateTime _extractCreatedDate(T object) {
    // Use reflection-like approach to get the created field
    // This is a bit hacky but necessary for generic sorting
    final objectStr = object.toString();
    final match = RegExp(r'created:\s*(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z?)').firstMatch(objectStr);
    if (match != null) {
      return DateTime.parse(match.group(1)!);
    }

    // Alternative: try to access as dynamic
    try {
      final dynamic obj = object;
      if (obj is Map && obj.containsKey('created')) {
        final created = obj['created'];
        if (created is DateTime) return created;
        if (created is String) return DateTime.parse(created);
      }
      // Try to access created property directly
      return (obj as dynamic).created as DateTime;
    } catch (e) {
      // If all else fails, use current time (objects will be in random order)
      return DateTime.now();
    }
  }

  @override
  Stream<T> stream(String id) {
    // TODO: Implement DynamoDB Streams or polling-based approach
    // For now, return a simple polling stream similar to Firebase's approach
    final controller = StreamController<T>();
    bool hasEmitted = false;
    Timer? timer;

    void fetchAndEmit() async {
      try {
        final data = await get(id);
        hasEmitted = true;
        controller.add(data);
      } catch (e) {
        if (!hasEmitted && e is RepositoryException && e.message.contains('not found')) {
          controller.addError(RepositoryException.notFound(id));
        } else if (hasEmitted && e is RepositoryException && e.message.contains('not found')) {
          // Document was deleted, close the stream
          controller.close();
        } else {
          controller.addError(e);
        }
      }
    }

    controller.onListen = () {
      // Emit initial data
      fetchAndEmit();
      // Set up polling (every 2 seconds)
      timer = Timer.periodic(Duration(seconds: 2), (_) => fetchAndEmit());
    };

    controller.onCancel = () => timer?.cancel();

    return controller.stream;
  }

  @override
  Stream<List<T>> streamQuery({Query query = const AllQuery()}) {
    // Similar to Firebase approach with polling
    late StreamController<List<T>> controller;
    Timer? timer;

    controller = StreamController<List<T>>(
      onListen: () async {
        // Emit initial data immediately
        try {
          final initialData = await this.query(query: query);
          controller.add(initialData);
        } catch (e) {
          controller.addError(e);
        }

        // Set up polling (every 5 seconds)
        timer = Timer.periodic(Duration(seconds: 5), (_) async {
          try {
            final data = await this.query(query: query);
            controller.add(data);
          } catch (e) {
            controller.addError(e);
          }
        });
      },
      onCancel: () => timer?.cancel(),
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
