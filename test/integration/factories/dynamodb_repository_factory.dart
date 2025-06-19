// ignore_for_file: avoid_print

import 'package:document_client/document_client.dart';
import 'package:kiss_dynamodb_repository/kiss_dynamodb_repository.dart';
import 'package:kiss_repository/kiss_repository.dart';
import 'package:kiss_repository_tests/kiss_repository_tests.dart';

import 'dynamodb_query_builder.dart';

class DynamoDBRepositoryFactory implements RepositoryFactory {
  static late DynamoDB _dynamoDB;
  static late DocumentClient _documentClient;
  static bool _initialized = false;
  Repository<ProductModel>? _repository;

  static const String _testTable = 'products';
  static const String _dynamodbUrl = 'http://localhost:8000';

  // Fake credentials (required by DynamoDB Local but not validated)
  static const String _fakeAccessKey = 'fakeAccessKey';
  static const String _fakeSecretKey = 'fakeSecretKey';
  static const String _fakeRegion = 'us-east-1';

  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize DynamoDB client with local endpoint
    _dynamoDB = DynamoDB(
      region: _fakeRegion,
      credentials: AwsClientCredentials(accessKey: _fakeAccessKey, secretKey: _fakeSecretKey),
      endpointUrl: _dynamodbUrl,
    );

    // Initialize Document Client for easier data handling
    _documentClient = DocumentClient(region: _fakeRegion, dynamoDB: _dynamoDB);

    // Create test table if it doesn't exist
    await _createTestTableIfNeeded();

    try {
      // Test DynamoDB connection by listing tables
      await _dynamoDB.listTables();
      print('✅ Connected to DynamoDB Local at $_dynamodbUrl');
    } catch (e) {
      throw Exception(
        'Failed to connect to DynamoDB Local. Make sure it\'s running at $_dynamodbUrl\n'
        'Run: ./scripts/start_emulator.sh\n'
        'Error: $e',
      );
    }

    _initialized = true;
    print('✅ DynamoDB repository initialized');
  }

  static Future<void> _createTestTableIfNeeded() async {
    try {
      // Check if table exists
      await _dynamoDB.describeTable(tableName: _testTable);
      print('✅ Test table "$_testTable" already exists');
    } catch (e) {
      // Table doesn't exist, create it
      print('🔨 Creating test table "$_testTable"...');

      await _dynamoDB.createTable(
        tableName: _testTable,
        keySchema: [KeySchemaElement(attributeName: 'id', keyType: KeyType.hash)],
        attributeDefinitions: [AttributeDefinition(attributeName: 'id', attributeType: ScalarAttributeType.s)],
        billingMode: BillingMode.payPerRequest,
      );

      // Wait for table to be active
      await _waitForTableActive();
      print('✅ Test table "$_testTable" created successfully');
    }
  }

  static Future<void> _waitForTableActive() async {
    while (true) {
      final response = await _dynamoDB.describeTable(tableName: _testTable);
      if (response.table?.tableStatus == TableStatus.active) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  Repository<ProductModel> createRepository() {
    if (!_initialized) {
      throw StateError('Factory not initialized. Call initialize() first.');
    }

    _repository = RepositoryDynamoDB<ProductModel>(
      client: _documentClient,
      tableName: _testTable,
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
      queryBuilder: TestDynamoDBProductQueryBuilder(),
    );
    return _repository!;
  }

  @override
  Future<void> cleanup() async {
    if (_repository == null) {
      print('🧹 Cleanup: No repository to clean');
      return;
    }

    try {
      // Scan all items in the table
      final scanResult = await _dynamoDB.scan(tableName: _testTable);
      final items = scanResult.items ?? [];
      print('🧹 Cleanup: Found ${items.length} items to delete');

      if (items.isNotEmpty) {
        // Delete all items
        for (final item in items) {
          final id = item['id']?.s;
          if (id != null) {
            await _dynamoDB.deleteItem(
              tableName: _testTable,
              key: {'id': AttributeValue(s: id)},
            );
          }
        }
        print('🧹 Cleanup: Deleted ${items.length} items successfully');
      } else {
        print('🧹 Cleanup: Table already empty');
      }
    } catch (e) {
      print('❌ Cleanup failed: $e');
    }
  }

  @override
  void dispose() {
    _repository?.dispose();
    _repository = null;
    _initialized = false;
  }
}
