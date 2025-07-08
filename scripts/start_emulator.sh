#!/bin/bash

# DynamoDB Local Setup Script
echo "🚀 Starting DynamoDB Local..."

# Check if Docker daemon is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker daemon is not running"
    echo "💡 Please start Docker Desktop or Docker daemon first"
    echo "   - On macOS: Open Docker Desktop application"
    echo "   - On Linux: sudo systemctl start docker"
    exit 1
fi

echo "✅ Docker daemon is running"

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create data directory if it doesn't exist
mkdir -p "$PROJECT_DIR/docker/dynamodb"

# Check if DynamoDB container is already running
cd "$SCRIPT_DIR"
if docker-compose ps | grep -q "dynamodb-local.*Up"; then
    echo "✅ DynamoDB Local container is already running"
elif docker ps -a --format "table {{.Names}}" | grep -q "dynamodb-local"; then
    echo "🔄 DynamoDB Local container exists but is stopped. Restarting..."
    docker-compose down
    docker-compose up -d
else
    echo "🆕 Starting new DynamoDB Local container..."
    docker-compose up -d
fi

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