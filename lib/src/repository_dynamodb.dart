import 'dart:async';

import 'package:document_client/document_client.dart';
import 'package:kiss_repository/kiss_repository.dart';

import 'utils/batch_operations.dart';
import 'utils/dynamodb_identified_object.dart';
import 'utils/object_extraction_helpers.dart';

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
      if (result.item.isEmpty) {
        throw RepositoryException.notFound(id);
      }
      return fromDynamoDB(result.item);
    } on ResourceNotFoundException {
      throw RepositoryException.notFound(id);
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
      if (currentResult.item.isEmpty) {
        throw RepositoryException.notFound(id);
      }
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
      QueryOutputDC result;

      if (query is AllQuery) {
        result = await client.scan(tableName: tableName);
      } else if (queryBuilder != null) {
        final scanParams = queryBuilder!.build(query);

        result = await client.scan(
          tableName: tableName,
          filterExpression: scanParams['filterExpression'] as String?,
          expressionAttributeNames: scanParams['expressionAttributeNames'] as Map<String, String>?,
          expressionAttributeValues: scanParams['expressionAttributeValues'] as Map<String, dynamic>?,
        );
      } else {
        throw RepositoryException(
          message:
              'Query builder required for custom queries. '
              'Please provide a QueryBuilder<Map<String, dynamic>>.',
        );
      }

      final items = result.items;
      final objects = items.map(fromDynamoDB).toList();

      objects.sort((a, b) => extractCreatedDate(b).compareTo(extractCreatedDate(a)));

      return objects;
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException(message: 'Failed to query records: $e');
    }
  }

  @override
  Stream<T> stream(String id) {
    throw UnimplementedError();
  }

  @override
  Stream<List<T>> streamQuery({Query query = const AllQuery()}) {
    throw UnimplementedError();
  }

  @override
  Future<Iterable<T>> addAll(Iterable<IdentifiedObject<T>> items) async {
    if (items.isEmpty) return [];

    try {
      final itemsList = items.toList();

      // Use DynamoDB BatchWriteItem for efficient bulk operations
      await batchWriteItems<T>(client: client, tableName: tableName, items: itemsList, toDynamoDB: toDynamoDB);

      // Return the added results
      final results = <T>[];
      for (final item in itemsList) {
        final data = toDynamoDB(item.object);
        data['id'] = item.id;
        results.add(fromDynamoDB(data));
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
    if (ids.isEmpty) return;

    try {
      // Use DynamoDB BatchWriteItem for efficient bulk deletions
      await batchDeleteItems(client: client, tableName: tableName, ids: ids);
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
