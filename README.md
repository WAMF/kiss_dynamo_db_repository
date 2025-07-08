# kiss_dynamodb_repository

A DynamoDB implementation of the `kiss_repository` interface for pure Dart applications.

## Overview

This package provides a DynamoDB backend implementation of the KISS repository pattern, designed for pure Dart applications that need AWS DynamoDB integration. Unlike Firebase (Flutter-focused) or PocketBase (real-time focused), this implementation targets server-side Dart, CLI tools, and applications requiring AWS ecosystem integration.

## ✅ Standard Repository Features

All implementations in the KISS repository family support these core features:

- **CRUD Operations**: `create()`, `read()`, `update()`, `delete()`
- **Bulk Operations**: `createMultiple()`, `updateMultiple()`, `deleteMultiple()`
- **Query Builder**: `query()` with filtering, sorting, pagination
- **Batch Operations**: Atomic multi-document transactions
- **Type Safety**: Full generic type support with compile-time safety
- **Error Handling**: Consistent exception types across all backends

## 🗄️ DynamoDB-Specific Features

### Pure Dart Environment
- **No Flutter Dependencies**: Works in any Dart environment (server, CLI, IoT)
- **Lightweight**: Minimal dependencies for maximum compatibility
- **Cross-Platform**: Runs on any platform supporting Dart

### AWS Ecosystem Integration
- **Production Ready**: Built for AWS production environments
- **Scalable**: Leverages DynamoDB's automatic scaling capabilities
- **Cost Effective**: Pay-per-use pricing model with generous free tier

### Local Development
- **DynamoDB Local**: Full local emulator using `scripts/docker-compose.yml`
- **Persistent Storage**: Data stored in `./docker/dynamodb/` survives container restarts
- **No AWS Account Required**: Develop entirely offline with dummy credentials
- **Shared Database**: Single database instance shared across all tables
- **Telemetry Disabled**: Runs with `-disableTelemetry` flag for privacy

### 📡 Streaming Architecture
- ❌ **No Streaming**: No real-time streaming capabilities
- ❌ **No Client Streams**: DynamoDB doesn't provide client-side real-time streams
- ⚠️ **Server-Side Only**: DynamoDB Streams are designed for AWS Lambda, not client applications
- ❌ **Polling Required**: Real-time updates require inefficient client polling
- ⚠️ **Complex Workarounds**: True streaming needs AWS infrastructure (API Gateway + Lambda + WebSocket)
- ✅ **Perfect for**: Batch processing, high-throughput applications, AWS-native services
- ❌ **Not suitable for**: Real-time collaborative applications, live dashboards

**Streaming Alternatives**: For real-time features, consider:
- `kiss_firebase_repository` - ✅ Multi-instance real-time streaming
- `kiss_pocketbase_repository` - ✅ Multi-instance real-time streaming
- `kiss_drift_repository` - ⚠️ Single-instance streaming only

## ⚠️ Other Limitations

### AWS-Specific Query Limitations
- **Case-sensitive queries**: DynamoDB is case-sensitive by default
- **Limited text search**: No built-in full-text search (consider AWS OpenSearch)
- **Complex joins**: NoSQL limitations apply

## 🚀 Quick Start

### Prerequisites

- **Dart SDK**: ^3.8.0 or higher
- **Docker Desktop**: Must be installed and running
  - Download from [docker.com](https://www.docker.com/products/docker-desktop/)
  - Ensure Docker Desktop is started before proceeding

### Basic Usage

```dart
import 'package:document_client/document_client.dart';
import 'package:kiss_dynamodb_repository/kiss_dynamodb_repository.dart';

// Initialize client
final client = DocumentClient(
  region: 'us-east-1',
  dynamoDB: DynamoDB(
    region: 'us-east-1',
    credentials: AwsClientCredentials(accessKey: 'key', secretKey: 'secret'),
    endpointUrl: 'http://localhost:8000', // For local development
  ),
);

// Create repository
final repository = RepositoryDynamoDB<MyModel>(
  client: client,
  tableName: 'my_table',
  fromDynamoDB: (item) => MyModel.fromMap(item),
  toDynamoDB: (model) => model.toMap(),
);
```

## 🔧 Development Setup

### 1. Start DynamoDB Local Emulator

```bash
# Start DynamoDB Local emulator
./scripts/start_emulator.sh
```

The emulator will:
- Download DynamoDB Local Docker image (~100MB first time)
- Start DynamoDB Local on port 8000
- Create persistent storage in `./docker/dynamodb/`
- Verify connection

### 2. Verify Emulator is Running

```bash
# Test connection (requires AWS CLI: brew install awscli)
aws dynamodb list-tables --endpoint-url http://localhost:8000
```

**Expected output:** `{"TableNames": []}`

### 3. Run Integration Tests

```bash
# In a separate terminal
./scripts/run_tests.sh
```

### Stop Emulator

```bash
./scripts/stop_dynamodb.sh
```

## 📖 Usage

### Repository Configuration

```dart
// Local development
final localRepo = RepositoryDynamoDB<MyModel>(
  client: DocumentClient(/* ... with endpointUrl: 'http://localhost:8000' */),
  tableName: 'my_table',
  fromDynamoDB: MyModel.fromMap,
  toDynamoDB: (model) => model.toMap(),
);

// Production
final prodRepo = RepositoryDynamoDB<MyModel>(
  client: DocumentClient(/* ... with AWS credentials */),
  tableName: 'prod_table',
  fromDynamoDB: MyModel.fromMap,
  toDynamoDB: (model) => model.toMap(),
);
```

### CRUD Operations

```dart
// Basic operations
final item = await repository.add(IdentifiedObject(id: 'id', object: myModel));
final retrieved = await repository.get('id');
final updated = await repository.update('id', (current) => current.copyWith(name: 'new'));
await repository.delete('id');

// Batch operations
await repository.addAll([IdentifiedObject(id: '1', object: model1)]);
await repository.updateAll([IdentifiedObject(id: '1', object: updatedModel)]);
await repository.deleteAll(['1', '2', '3']);
```

### Query Operations

```dart
// Query all items
final allItems = await repository.query();

// Custom queries need a QueryBuilder
class MyQueryBuilder implements QueryBuilder<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build(Query query) {
    if (query is QueryByName) {
      return {
        'filterExpression': 'contains(#name, :name)',
        'expressionAttributeNames': {'#name': 'name'},
        'expressionAttributeValues': {':name': query.name},
      };
    }
    return {}; // Fallback to scan all
  }
}

// Use with repository
final repository = RepositoryDynamoDB<MyModel>(
  // ... other params
  queryBuilder: MyQueryBuilder(),
);

final results = await repository.query(query: QueryByName('search'));
```

## 🔄 Comparison

For a detailed comparison of all KISS repository implementations, see the [main repository comparison table](https://github.com/clukes/kiss_repository#implementation-comparison).

## 📁 Example Application

See the [shared example application](https://github.com/clukes/kiss_repository/tree/main/example) for a complete implementation using all repository backends, including DynamoDB.

---

## Development Details

### Emulator Configuration
- **Endpoint**: `http://localhost:8000`
- **Credentials**: Any dummy credentials work with local emulator
- **Docker Image**: `amazon/dynamodb-local:2.5.2`
- **Container Name**: `dynamodb-local`
- **Storage**: Persistent volume mounted to `./docker/dynamodb/`
- **Flags**: `-sharedDb -dbPath ./data -disableTelemetry`
- **Port**: 8000 (configurable in `scripts/docker-compose.yml`)

### Available Scripts
- `./scripts/start_emulator.sh` - Start DynamoDB Local emulator
- `./scripts/run_tests.sh` - Run integration tests
- `./scripts/stop_dynamodb.sh` - Stop emulator cleanly

---

*This package is part of the KISS repository family. For other implementations, see:*
- *[Core Interface](https://github.com/clukes/kiss_repository) - `kiss_repository`*
- *[Firebase/Firestore](https://github.com/clukes/kiss_firebase_repository) - `kiss_firebase_repository`*
- *[PocketBase](https://github.com/clukes/kiss_pocketbase_repository) - `kiss_pocketbase_repository`*