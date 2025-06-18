import 'package:test/test.dart';
import 'package:kiss_repository_tests/test.dart';

import 'factories/dynamodb_repository_factory.dart';

void main() {
  setUpAll(() async {
    await DynamoDBRepositoryFactory.initialize();
  });

  final factory = DynamoDBRepositoryFactory();
  final tester = RepositoryTester('DynamoDB', factory, () {});

  // ignore: cascade_invocations
  tester.run();
}
