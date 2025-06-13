#!/bin/bash

# DynamoDB Repository - Integration Tests Runner
# Assumes DynamoDB Local emulator is already running on port 8000

cd "$(dirname "$0")/.."

echo "🧪 Running DynamoDB Repository Integration Tests..."

# Check if DynamoDB Local is running
if ! curl -s http://localhost:8000 > /dev/null 2>&1; then
    echo "❌ DynamoDB Local emulator is not running on port 8000"
    echo "💡 Start it first with: ./scripts/start_emulator.sh"
    exit 1
fi

echo "✅ DynamoDB Local emulator detected"

# Run integration tests
echo "🚀 Running integration tests..."
dart test test/integration/all_integration_tests.dart 