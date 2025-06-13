import 'package:document_client/document_client.dart';
import 'package:kiss_repository/kiss_repository.dart';

import 'type_converter.dart';

/// Maximum number of items per BatchGetItem request
/// https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_BatchGetItem.html
const int _batchGetItemLimit = 100;

/// Maximum number of items per BatchWriteItem request
/// https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_BatchWriteItem.html
const int _batchWriteItemLimit = 25;

const int _retryBackoffMs = 100;

Future<void> checkItemsExist({
  required DocumentClient client,
  required String tableName,
  required Iterable<String> ids,
}) async {
  final dynamoDB = client.dynamoDB;
  final idsList = ids.toList();

  for (int i = 0; i < idsList.length; i += _batchGetItemLimit) {
    final batchIds = idsList.skip(i).take(_batchGetItemLimit);
    final keys = batchIds.map((id) => {'id': AttributeValue(s: id)}).toList();

    final response = await dynamoDB.batchGetItem(requestItems: {tableName: KeysAndAttributes(keys: keys)});
    var returnedItems = response.responses?[tableName] ?? [];

    var unprocessedKeys = response.unprocessedKeys?[tableName]?.keys ?? <Map<String, AttributeValue>>[];

    while (unprocessedKeys.isNotEmpty) {
      print('🔁 Retrying ${unprocessedKeys.length} unprocessed read keys...');
      await Future.delayed(Duration(milliseconds: _retryBackoffMs));
      final retryResponse = await dynamoDB.batchGetItem(
        requestItems: {tableName: KeysAndAttributes(keys: unprocessedKeys)},
      );

      final retryItems = retryResponse.responses?[tableName] ?? [];
      returnedItems.addAll(retryItems);

      unprocessedKeys = retryResponse.unprocessedKeys?[tableName]?.keys ?? <Map<String, AttributeValue>>[];
    }

    if (returnedItems.length != batchIds.length) {
      final returnedIds = returnedItems.map((item) => item['id']?.s).where((id) => id != null).toSet();

      final missingIds = batchIds.where((id) => !returnedIds.contains(id)).toList();

      if (missingIds.isNotEmpty) {
        throw RepositoryException.notFound(missingIds.first);
      }
    }
  }
}

Future<void> batchWriteItems<T>({
  required DocumentClient client,
  required String tableName,
  required List<IdentifiedObject<T>> items,
  required Map<String, dynamic> Function(T object) toDynamoDB,
}) async {
  final dynamoDB = client.dynamoDB;

  for (int i = 0; i < items.length; i += _batchWriteItemLimit) {
    final batchItems = items.skip(i).take(_batchWriteItemLimit).toList();
    final writeRequests = <WriteRequest>[];

    for (final item in batchItems) {
      final data = toDynamoDB(item.object);

      final attributeValueMap = <String, AttributeValue>{};
      for (final entry in data.entries) {
        attributeValueMap[entry.key] = toAttributeValue(entry.value);
      }

      writeRequests.add(WriteRequest(putRequest: PutRequest(item: attributeValueMap)));
    }

    final response = await dynamoDB.batchWriteItem(requestItems: {tableName: writeRequests});

    var unprocessed = response.unprocessedItems?[tableName] ?? <WriteRequest>[];

    while (unprocessed.isNotEmpty) {
      print('🔁 Retrying ${unprocessed.length} unprocessed write items...');
      await Future.delayed(Duration(milliseconds: _retryBackoffMs));
      final retryResponse = await dynamoDB.batchWriteItem(requestItems: {tableName: unprocessed});
      unprocessed = retryResponse.unprocessedItems?[tableName] ?? <WriteRequest>[];
    }
  }
}

Future<void> batchDeleteItems({
  required DocumentClient client,
  required String tableName,
  required Iterable<String> ids,
}) async {
  final dynamoDB = client.dynamoDB;

  final idsList = ids.toList();

  for (int i = 0; i < idsList.length; i += _batchWriteItemLimit) {
    final batchIds = idsList.skip(i).take(_batchWriteItemLimit).toList();
    final writeRequests = <WriteRequest>[];

    for (final id in batchIds) {
      final key = {'id': AttributeValue(s: id)};
      writeRequests.add(WriteRequest(deleteRequest: DeleteRequest(key: key)));
    }

    final response = await dynamoDB.batchWriteItem(requestItems: {tableName: writeRequests});

    var unprocessed = response.unprocessedItems?[tableName] ?? <WriteRequest>[];

    while (unprocessed.isNotEmpty) {
      print('🔁 Retrying ${unprocessed.length} unprocessed delete items...');
      await Future.delayed(Duration(milliseconds: _retryBackoffMs));
      final retryResponse = await dynamoDB.batchWriteItem(requestItems: {tableName: unprocessed});
      unprocessed = retryResponse.unprocessedItems?[tableName] ?? <WriteRequest>[];
    }
  }
}
