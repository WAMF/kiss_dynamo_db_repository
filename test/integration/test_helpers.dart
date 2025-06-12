import 'package:document_client/document_client.dart';
import 'package:kiss_dynamodb_repository/kiss_dynamodb_repository.dart';
import 'package:kiss_repository/kiss_repository.dart';

import '../../../kiss_repository/shared_test_logic/data/product_model.dart';
import 'dynamodb_query_builder.dart';

class IntegrationTestHelpers {
  static late DynamoDB dynamoDB;
  static late DocumentClient documentClient;
  static late Repository<ProductModel> repository;
  static const String testTable = 'products';
  static const String dynamodbUrl = 'http://localhost:8000';

  // Fake credentials (required by DynamoDB Local but not validated)
  static const String fakeAccessKey = 'fakeAccessKey';
  static const String fakeSecretKey = 'fakeSecretKey';
  static const String fakeRegion = 'us-east-1';

  static Future<void> initializeDynamoDB() async {
    // Initialize DynamoDB client with local endpoint
    dynamoDB = DynamoDB(
      region: fakeRegion,
      credentials: AwsClientCredentials(accessKey: fakeAccessKey, secretKey: fakeSecretKey),
      endpointUrl: dynamodbUrl,
    );

    // Initialize Document Client for easier data handling
    documentClient = DocumentClient(region: fakeRegion, dynamoDB: dynamoDB);

    // Create test table if it doesn't exist
    await _createTestTableIfNeeded();

    // Create repository instance with DynamoDB-specific query builder
    repository = RepositoryDynamoDB<ProductModel>(
      client: documentClient,
      tableName: testTable,
      fromDynamoDB: (item) => ProductModel(
        id: item['id'] as String,
        name: item['name'] as String,
        price: (item['price'] as num).toDouble(),
        description: item['description'] as String? ?? '',
        created: DateTime.parse(item['created'] as String),
      ),
      toDynamoDB: (productModel) => {
        'id': productModel.id,
        'name': productModel.name,
        'price': productModel.price,
        'description': productModel.description,
        'created': productModel.created.toIso8601String(),
      },
      queryBuilder: DynamoDBProductModelQueryBuilder(),
    );
  }

  static Future<void> _createTestTableIfNeeded() async {
    try {
      // Check if table exists
      await dynamoDB.describeTable(tableName: testTable);
      print('✅ Test table "$testTable" already exists');
    } catch (e) {
      // Table doesn't exist, create it
      print('🔨 Creating test table "$testTable"...');

      await dynamoDB.createTable(
        tableName: testTable,
        keySchema: [KeySchemaElement(attributeName: 'id', keyType: KeyType.hash)],
        attributeDefinitions: [AttributeDefinition(attributeName: 'id', attributeType: ScalarAttributeType.s)],
        billingMode: BillingMode.payPerRequest,
      );

      // Wait for table to be active
      await _waitForTableActive();
      print('✅ Test table "$testTable" created successfully');
    }
  }

  static Future<void> _waitForTableActive() async {
    while (true) {
      final response = await dynamoDB.describeTable(tableName: testTable);
      if (response.table?.tableStatus == TableStatus.active) {
        break;
      }
      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  static Future<void> clearTestTable() async {
    try {
      // Scan all items in the table
      final scanResult = await dynamoDB.scan(tableName: testTable);
      final items = scanResult.items ?? [];

      if (items.isEmpty) {
        return;
      }

      // Delete all items
      for (final item in items) {
        final id = item['id']?.s;
        if (id != null) {
          await dynamoDB.deleteItem(
            tableName: testTable,
            key: {'id': AttributeValue(s: id)},
          );
        }
      }

      print('🧹 Cleared ${items.length} test records');
    } catch (e) {
      print('ℹ️ Table clear: $e');
    }
  }

  static Future<void> setupIntegrationTests() async {
    await initializeDynamoDB();

    try {
      // Test DynamoDB connection by listing tables
      await dynamoDB.listTables();
      print('✅ Connected to DynamoDB Local at $dynamodbUrl');
    } catch (e) {
      throw Exception(
        'Failed to connect to DynamoDB Local. Make sure it\'s running at $dynamodbUrl\n'
        'Run: ./scripts/start_dynamodb.sh\n'
        'Error: $e',
      );
    }

    print('🎯 Integration tests ready to run');
  }

  static Future<void> tearDownIntegrationTests() async {
    try {
      await clearTestTable();
      print('✅ Integration test cleanup completed');
    } catch (e) {
      print('ℹ️ Cleanup error (may be harmless): $e');
    }
  }
}
