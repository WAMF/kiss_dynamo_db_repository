import 'package:test/test.dart';
import 'integration/test_helpers.dart';

void main() {
  test('DynamoDB Local connection test', () async {
    try {
      await IntegrationTestHelpers.setupIntegrationTests();
      print('🎉 DynamoDB connection test passed!');
    } catch (e) {
      print('❌ DynamoDB connection test failed: $e');
      rethrow;
    } finally {
      await IntegrationTestHelpers.tearDownIntegrationTests();
    }
  });
}
