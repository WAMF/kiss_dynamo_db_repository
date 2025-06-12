import 'package:document_client/document_client.dart';
import 'package:kiss_repository/kiss_repository.dart';

import 'type_converter.dart';

/// Check that all items exist using BatchGetItem
Future<void> checkItemsExist({
  required DocumentClient client,
  required String tableName,
  required Iterable<String> ids,
}) async {
  const int batchSize = 100; // DynamoDB BatchGetItem limit
  final idsList = ids.toList();

  for (int i = 0; i < idsList.length; i += batchSize) {
    final batchIds = idsList.skip(i).take(batchSize);
    final keys = batchIds.map((id) => {'id': AttributeValue(s: id)}).toList();

    // Access the underlying DynamoDB client from DocumentClient
    final dynamoDB = client.dynamoDB;

    final response = await dynamoDB.batchGetItem(requestItems: {tableName: KeysAndAttributes(keys: keys)});

    final returnedItems = response.responses?[tableName] ?? [];

    // Check if any items are missing
    if (returnedItems.length != batchIds.length) {
      final returnedIds = returnedItems.map((item) => item['id']?.s).where((id) => id != null).toSet();

      final missingIds = batchIds.where((id) => !returnedIds.contains(id)).toList();

      if (missingIds.isNotEmpty) {
        throw RepositoryException.notFound(missingIds.first);
      }
    }
  }
}

/// Batch write items using BatchWriteItem
Future<void> batchWriteItems<T>({
  required DocumentClient client,
  required String tableName,
  required List<IdentifiedObject<T>> items,
  required Map<String, dynamic> Function(T object) toDynamoDB,
}) async {
  const int batchSize = 25; // DynamoDB BatchWriteItem limit

  for (int i = 0; i < items.length; i += batchSize) {
    final batchItems = items.skip(i).take(batchSize).toList();
    final writeRequests = <WriteRequest>[];

    for (final item in batchItems) {
      final data = toDynamoDB(item.object);
      data['id'] = item.id;

      // Convert to AttributeValue map
      final attributeValueMap = <String, AttributeValue>{};
      for (final entry in data.entries) {
        attributeValueMap[entry.key] = toAttributeValue(entry.value);
      }

      writeRequests.add(WriteRequest(putRequest: PutRequest(item: attributeValueMap)));
    }

    // Execute batch write using the underlying DynamoDB client
    final dynamoDB = client.dynamoDB;
    await dynamoDB.batchWriteItem(requestItems: {tableName: writeRequests});
  }
}

/// Batch delete items using BatchWriteItem with DeleteRequest
Future<void> batchDeleteItems({
  required DocumentClient client,
  required String tableName,
  required Iterable<String> ids,
}) async {
  const int batchSize = 25; // DynamoDB BatchWriteItem limit
  final idsList = ids.toList();

  for (int i = 0; i < idsList.length; i += batchSize) {
    final batchIds = idsList.skip(i).take(batchSize).toList();
    final writeRequests = <WriteRequest>[];

    for (final id in batchIds) {
      final key = {'id': AttributeValue(s: id)};
      writeRequests.add(WriteRequest(deleteRequest: DeleteRequest(key: key)));
    }

    // Execute batch delete using the underlying DynamoDB client
    final dynamoDB = client.dynamoDB;
    await dynamoDB.batchWriteItem(requestItems: {tableName: writeRequests});
  }
}
