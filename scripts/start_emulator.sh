#!/bin/bash

# DynamoDB Local Setup Script
echo "🚀 Starting DynamoDB Local..."

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create data directory if it doesn't exist
mkdir -p "$PROJECT_DIR/docker/dynamodb"

# Start DynamoDB Local using Docker Compose
cd "$SCRIPT_DIR"
docker-compose up -d

# Wait a moment for container to start
sleep 3

# Check if DynamoDB Local is running
echo "🔍 Checking if DynamoDB Local is running..."
if curl -s http://localhost:8000 > /dev/null 2>&1; then
    echo "✅ DynamoDB Local is running on http://localhost:8000"
    
    # Test with AWS CLI if available
    if command -v aws &> /dev/null; then
        echo "🧪 Testing with AWS CLI..."
        aws dynamodb list-tables --endpoint-url http://localhost:8000 2>/dev/null && echo "✅ AWS CLI connection successful"
    else
        echo "💡 Install AWS CLI to test connection: brew install awscli"
    fi
else
    echo "❌ DynamoDB Local failed to start"
    docker-compose logs
fi 