import 'package:kiss_repository_tests/kiss_repository_tests.dart';

import 'factories/dynamodb_repository_factory.dart';

void main() {
  runRepositoryTests(implementationName: 'DynamoDB', factoryProvider: DynamoDBRepositoryFactory.new, cleanup: () {});
}
