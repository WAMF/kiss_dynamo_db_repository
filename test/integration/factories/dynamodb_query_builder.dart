import 'package:kiss_repository/kiss_repository.dart';
import 'package:kiss_repository_tests/kiss_repository_tests.dart';

/// DynamoDB-specific query builder for ProductModel tests
/// Returns a Map with DynamoDB scan parameters instead of a string like PocketBase
class TestDynamoDBProductQueryBuilder implements QueryBuilder<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build(Query query) {
    if (query is QueryByName) {
      return {
        'filterExpression': 'contains(#name, :name)',
        'expressionAttributeNames': {'#name': 'name'},
        'expressionAttributeValues': {':name': query.namePrefix},
      };
    }

    if (query is QueryByPriceRange) {
      final conditions = <String>[];
      final attributeValues = <String, dynamic>{};

      if (query.minPrice != null) {
        conditions.add('#price >= :minPrice');
        attributeValues[':minPrice'] = query.minPrice;
      }
      if (query.maxPrice != null) {
        conditions.add('#price <= :maxPrice');
        attributeValues[':maxPrice'] = query.maxPrice;
      }

      return {
        'filterExpression': conditions.join(' AND '),
        'expressionAttributeNames': {'#price': 'price'},
        'expressionAttributeValues': attributeValues,
      };
    }

    // Return empty map for unknown queries - will trigger AllQuery behavior
    return {};
  }
}
