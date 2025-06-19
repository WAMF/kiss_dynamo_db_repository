import 'package:test/test.dart';
import 'package:kiss_repository/kiss_repository.dart';
import 'package:kiss_repository_tests/kiss_repository_tests.dart';

import 'factories/dynamodb_repository_factory.dart';

void main() {
  late DynamoDBRepositoryFactory factory;
  late Repository<ProductModel> repository;

  setUpAll(() async {
    await DynamoDBRepositoryFactory.initialize();
    factory = DynamoDBRepositoryFactory();
    repository = factory.createRepository();
  });

  setUp(() async {
    await factory.cleanup();
  });

  group('DynamoDB-Specific Behavior', () {
    test('addAutoIdentified without updateObjectWithId returns object with server-generated ID', () async {
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
