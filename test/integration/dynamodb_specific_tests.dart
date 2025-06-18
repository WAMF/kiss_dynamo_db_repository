import 'package:test/test.dart';

import '../../../kiss_repository/shared_test_logic/data/product_model.dart';
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

  group('DynamoDB-Specific Behavior', () {
    test('addAutoIdentified without updateObjectWithId returns object with server-generated ID', () async {
      final repository = IntegrationTestHelpers.repository;
      final productModel = ProductModel.create(name: 'ProductX', price: 9.99);

      final addedObject = await repository.addAutoIdentified(productModel);

      expect(addedObject.id, isNotEmpty);
      expect(addedObject.name, equals('ProductX'));
      expect(addedObject.price, equals(9.99));

      // Verify the object was actually saved and can be retrieved
      final retrieved = await repository.get(addedObject.id);
      expect(retrieved.id, equals(addedObject.id));
      expect(retrieved.name, equals('ProductX'));

      // Note: DynamoDB always returns the complete object with server-generated ID
      // because the ID is the primary key and part of the item structure
    });
  });
}
