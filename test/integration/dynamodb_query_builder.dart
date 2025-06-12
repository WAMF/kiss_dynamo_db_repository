import 'package:kiss_repository/kiss_repository.dart';

import '../../../kiss_repository/shared_test_logic/data/queries.dart';

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

    if (query is QueryByPriceGreaterThan) {
      return {
        'filterExpression': '#price > :price',
        'expressionAttributeNames': {'#price': 'price'},
        'expressionAttributeValues': {':price': query.price},
      };
    }

    if (query is QueryByPriceLessThan) {
      return {
        'filterExpression': '#price < :price',
        'expressionAttributeNames': {'#price': 'price'},
        'expressionAttributeValues': {':price': query.price},
      };
    }

    if (query is QueryByCreatedAfter) {
      return {
        'filterExpression': '#created >= :created',
        'expressionAttributeNames': {'#created': 'created'},
        'expressionAttributeValues': {':created': query.date.toIso8601String()},
      };
    }

    if (query is QueryByCreatedBefore) {
      return {
        'filterExpression': '#created <= :created',
        'expressionAttributeNames': {'#created': 'created'},
        'expressionAttributeValues': {':created': query.date.toIso8601String()},
      };
    }

    // Return empty map for unknown queries - will trigger AllQuery behavior
    return {};
  }
}
