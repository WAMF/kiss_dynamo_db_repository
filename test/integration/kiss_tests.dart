import 'package:test/test.dart';

import '../../../kiss_repository/test/integration/kiss_dart_tests.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await IntegrationTestHelpers.setupIntegrationTests();
  });

  tearDownAll(() async {
    await IntegrationTestHelpers.tearDownIntegrationTests();
  });

  setUp(() async {
    await IntegrationTestHelpers.clearTestTable();
  });

  group('DynamoDB Repository - Centralized CRUD Tests', () {
    runDartCrudTests(() => IntegrationTestHelpers.repository);
  });

  group('Batch Operations Tests', () {
    runDartBatchTests(() => IntegrationTestHelpers.repository);
  });

  group('Query Filtering Tests', () {
    runDartQueryTests(() => IntegrationTestHelpers.repository);
  });

  group('Streaming Tests', () {
    runDartStreamingTests(() => IntegrationTestHelpers.repository);
  });

  group('ID Management Tests', () {
    runDartIdTests(() => IntegrationTestHelpers.repository);
  });
}
