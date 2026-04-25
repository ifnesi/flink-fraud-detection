#!/bin/bash

# Stop Confluent Platform Demo - Fraud Detection
# This script stops all Confluent Platform Docker containers

set -e

echo "=========================================="
echo "Stopping Confluent Platform Fraud Detection Demo"
echo "=========================================="
echo ""

# Check if docker directory exists
if [ ! -d "docker" ]; then
    echo "❌ Error: docker directory not found!"
    echo ""
    exit 1
fi

# Deactivate virtual environment if active
if [[ "$VIRTUAL_ENV" != "" ]]; then
    echo "Deactivating Python virtual environment..."
    deactivate 2>/dev/null || true
fi

# Stop Docker containers
echo "🐳 Stopping Confluent Platform Docker containers..."
echo ""
cd docker
docker compose down
cd ..

echo ""
echo "✅ All Confluent Platform containers have been stopped successfully!"
echo ""
