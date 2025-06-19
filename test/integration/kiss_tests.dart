import 'package:test/test.dart';
import 'package:kiss_repository_tests/kiss_repository_tests.dart';

import 'factories/dynamodb_repository_factory.dart';

void main() {
  setUpAll(() async {
    await DynamoDBRepositoryFactory.initialize();
  });

  runRepositoryTests(
    implementationName: 'DynamoDB',
    factoryProvider: DynamoDBRepositoryFactory.new,
    cleanup: () {},
  );
}
