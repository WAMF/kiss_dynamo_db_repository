#!/bin/bash

# DynamoDB Local Stop Script
echo "🛑 Stopping DynamoDB Local..."

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Stop DynamoDB Local using Docker Compose
cd "$SCRIPT_DIR"
docker-compose down

echo "✅ DynamoDB Local stopped" 