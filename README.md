# kiss_dynamodb_repository

A DynamoDB implementation of the `kiss_repository` interface for Dart applications.

## Features

- **Pure Dart**: No Flutter dependencies, works in any Dart environment
- **Local Development**: Use DynamoDB Local emulator for cost-free development
- **Repository Pattern**: Implements the standard `kiss_repository` interface
- **Type Safe**: Full generic type support with proper error handling

## Getting Started

### Prerequisites

- Dart SDK ^3.8.0
- **Docker Desktop**: Must be installed and running before proceeding
  - Download from [docker.com](https://www.docker.com/products/docker-desktop/)
  - Ensure Docker Desktop is started before running DynamoDB Local

### Running DynamoDB Local Emulator

```bash
# Start DynamoDB Local (downloads image first time ~100MB)
./scripts/start_dynamodb.sh
```

The start script will:
- Create necessary directories
- Start DynamoDB Local on port 8000  
- Verify it's running
- Test connection if AWS CLI is available

```bash
# Stop DynamoDB Local  
./scripts/stop_dynamodb.sh
```


### Verify DynamoDB Local is Running

```bash
# Test connection (requires AWS CLI: brew install awscli)
aws dynamodb list-tables --endpoint-url http://localhost:8000
```

**Expected output:** `{"TableNames": []}`

## Usage

```dart
import 'package:kiss_dynamodb_repository/kiss_dynamodb_repository.dart';

// TODO: Usage examples will be added during implementation
```

## Development

- **Emulator Endpoint**: `http://localhost:8000`
- **No AWS Credentials Required**: Local emulator accepts any credentials
- **Persistent Data**: Docker volume stores data in `./docker/dynamodb/`
- **Port**: Default port 8000 (configurable with `-port` option)

## Scripts

- `./scripts/start_dynamodb.sh` - Start DynamoDB Local with setup
- `./scripts/stop_dynamodb.sh` - Stop DynamoDB Local cleanly
- `./scripts/docker-compose.yml` - Docker Compose configuration

## Additional Information

This package is part of the KISS repository family:
- `kiss_repository` - Core interfaces
- `kiss_firebase_repository` - Firestore implementation  
- `kiss_pocketbase_repository` - PocketBase implementation
- `kiss_dynamodb_repository` - DynamoDB implementation (this package)


### ⚠️ Streaming Not Implemented

**Real-time streaming capabilities (`stream()` and `streamQuery()`) are not implemented in this version.**

These methods will throw `UnimplementedError` when called. This is due to the architectural complexity required for proper DynamoDB streaming, which would need:

- DynamoDB Streams configuration
- AWS Lambda functions for stream processing  
- WebSocket or similar real-time communication layer

For real-time updates, consider using:
- **Firebase/Firestore** via `kiss_firebase_repository`
- **PocketBase** via `kiss_pocketbase_repository`  
- Implementing a custom streaming solution with AWS infrastructure

#### Future Implementation: Production Architecture

For reference, a proper DynamoDB streaming implementation would require this architecture:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Dart Client   │◄──►│  API Gateway    │◄──►│  Lambda Function│
│  (WebSocket)    │    │  (WebSocket)    │    │ (Stream Processor)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        ▲
                                                        │
                                              ┌─────────────────┐
                                              │ DynamoDB Stream │
                                              │   (Pull-based)  │
                                              └─────────────────┘
```

**Required AWS Infrastructure:**
1. **DynamoDB Stream** - Captures table changes (INSERT/MODIFY/DELETE events)
2. **AWS Lambda Function** - Processes stream events and filters by subscription
3. **API Gateway WebSocket API** - Manages persistent client connections
4. **Connection Management** - Store client subscriptions and connection IDs

**Why Client-Side Polling Doesn't Work:**
- **DynamoDB Streams** are server-side, pull-based mechanisms designed for AWS Lambda
- **Client applications** expect push-based, real-time updates over persistent connections
- **Polling approaches** are inefficient, not truly real-time, and don't scale

This architectural requirement is why streaming is not implemented in this repository version.