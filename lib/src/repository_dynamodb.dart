import 'dart:async';

import 'package:document_client/document_client.dart';
import 'package:kiss_repository/kiss_repository.dart';
import 'package:uuid/uuid.dart';

/// Special IdentifiedObject subclass that generates DynamoDB IDs on-demand
class DynamoDBIdentifiedObject<T> extends IdentifiedObject<T> {
  DynamoDBIdentifiedObject(T object, this._updateObjectWithId) : super('', object);

  final T Function(T object, String id) _updateObjectWithId;
  String? _cachedId;
  T? _cachedUpdatedObject;

  @override
  String get id {
    _cachedId ??= _generateDynamoDBId();
    return _cachedId!;
  }

  @override
  T get object {
    if (_cachedUpdatedObject == null) {
      final generatedId = id; // This will generate and cache the ID if needed
      _cachedUpdatedObject = _updateObjectWithId(super.object, generatedId);
    }
    return _cachedUpdatedObject!;
  }

  /// Generates a UUID for DynamoDB (similar to Firestore document IDs)
  String _generateDynamoDBId() {
    return const Uuid().v4();
  }

  /// Convenience factory method for creating objects with auto-generated IDs
  factory DynamoDBIdentifiedObject.create(T object, T Function(T object, String id) updateObjectWithId) =>
      DynamoDBIdentifiedObject(object, updateObjectWithId);
}

// Type conversion helpers (similar to Firebase implementation)
dynamic _dynamoDbToDartTypeConversion(dynamic value) {
  if (value is String) {
    // Try to parse ISO 8601 datetime strings
    if (DateTime.tryParse(value) != null) {
      return DateTime.parse(value);
    }
  }
  if (value is Map<String, dynamic>) {
    final entries = value.entries.map((entry) {
      return MapEntry<String, dynamic>(entry.key, _dynamoDbToDartTypeConversion(entry.value));
    });
    return Map<String, dynamic>.fromEntries(entries);
  }
  if (value is List) {
    return value.map(_dynamoDbToDartTypeConversion).toList();
  }
  return value;
}

dynamic _dartToDynamoDbTypeConversion(dynamic value) {
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Map<String, dynamic>) {
    final entries = value.entries.map((entry) {
      return MapEntry<String, dynamic>(entry.key, _dartToDynamoDbTypeConversion(entry.value));
    });
    return Map<String, dynamic>.fromEntries(entries);
  }
  if (value is List) {
    return value.map(_dartToDynamoDbTypeConversion).toList();
  }
  return value;
}

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
  final QueryBuilder<String>? queryBuilder;

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
        return items.map((item) => fromDynamoDB(item)).toList();
      } else if (queryBuilder != null) {
        // TODO: Implement query builder support later
        throw RepositoryException(
          message: 'Custom queries not yet implemented for DynamoDB. Only AllQuery is currently supported.',
        );
      } else {
        throw RepositoryException(
          message:
              'Query builder required for custom queries. '
              'Please provide a QueryBuilder<String> in the repository constructor.',
        );
      }
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException(message: 'Failed to query records: $e');
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
    try {
      final results = <T>[];

      for (final item in items) {
        final data = toDynamoDB(item.object);
        data['id'] = item.id;

        await client.put(tableName: tableName, item: data);

        results.add(fromDynamoDB(data));
      }

      return results;
    } catch (e) {
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
