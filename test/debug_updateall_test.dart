import 'package:test/test.dart';
import 'integration/test_helpers.dart';
import '../../kiss_repository/shared_test_logic/data/product_model.dart';
import 'package:kiss_repository/kiss_repository.dart';

void main() {
  test('Debug updateAll behavior', () async {
    await IntegrationTestHelpers.setupIntegrationTests();

    try {
      // Create one item
      final existingProduct = ProductModel.create(name: 'Existing Product', price: 10.0);
      final existingId = await IntegrationTestHelpers.repository.addAutoIdentified(existingProduct);
      print('✅ Created existing item with ID: ${existingId.id}');

      // Try to update both existing and non-existing items
      final items = [
        IdentifiedObject(existingId.id, existingProduct.copyWith(name: 'Updated Existing')),
        IdentifiedObject('non_existent_id', ProductModel.create(name: 'Updated Non-Existent', price: 9.99)),
      ];

      print('🔍 Attempting updateAll...');
      try {
        final results = await IntegrationTestHelpers.repository.updateAll(items);
        print('❌ updateAll succeeded when it should have failed!');
        print('Results: ${results.length} items');
        for (final result in results) {
          print('  - ${result.id}: ${result.name}');
        }
      } catch (e) {
        print('✅ updateAll failed as expected: $e');
      }
    } finally {
      await IntegrationTestHelpers.tearDownIntegrationTests();
    }
  });
}
