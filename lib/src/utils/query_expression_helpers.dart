import 'package:kiss_repository/kiss_repository.dart';

/// Build expression attribute values for DynamoDB filter expressions
Map<String, dynamic>? buildExpressionAttributeValues(Query query) {
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
Map<String, String>? buildExpressionAttributeNames(Query query) {
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
