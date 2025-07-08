import 'package:kiss_repository/kiss_repository.dart';

/// Build expression attribute values for DynamoDB filter expressions
Map<String, dynamic>? buildExpressionAttributeValues(Query query) {
  // Import the query types
  if (query.runtimeType.toString().contains('QueryByName')) {
    final dynamic queryByName = query;
    return {':namePrefix': queryByName.namePrefix};
  }
  if (query.runtimeType.toString().contains('QueryByPriceRange')) {
    final dynamic queryByPriceRange = query;
    final values = <String, dynamic>{};
    if (queryByPriceRange.minPrice != null) {
      values[':minPrice'] = queryByPriceRange.minPrice;
    }
    if (queryByPriceRange.maxPrice != null) {
      values[':maxPrice'] = queryByPriceRange.maxPrice;
    }
    return values.isNotEmpty ? values : null;
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
  return null;
}
