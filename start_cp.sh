#!/bin/bash

# Start Confluent Platform Demo - Fraud Detection
# This script starts Confluent Platform using Docker and launches the web application

set -e

# Function to open URL in default browser (cross-platform)
open_browser() {
    if command -v open > /dev/null; then
        # macOS
        open "$1"
    elif command -v xdg-open > /dev/null; then
        # Linux
        xdg-open "$1"
    elif command -v start > /dev/null; then
        # Windows (Git Bash)
        start "$1"
    else
        echo "⚠️  Could not detect browser command. Please open manually: $1"
    fi
}

echo "=========================================="
echo "Starting Confluent Platform Fraud Detection Demo"
echo "=========================================="
echo ""

# Check if virtual environment exists
if [ ! -d ".venv" ]; then
    echo "❌ Error: Python virtual environment not found!"
    echo ""
    echo "Please run the installation steps first:"
    echo "  python3 -m venv .venv"
    echo "  source .venv/bin/activate"
    echo "  pip install --upgrade pip"
    echo "  pip install -r src/requirements.txt"
    echo "  deactivate"
    echo ""
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running!"
    echo ""
    echo "Please start Docker Desktop and try again."
    echo ""
    exit 1
fi

# Step 1: Start Confluent Platform Docker containers
echo "🐳 Step 1: Starting Confluent Platform Docker containers..."
echo ""
cd docker
docker compose up -d
cd ..

echo ""
echo "✅ Confluent Platform containers started successfully!"
echo ""
echo "📊 Confluent Control Center: http://localhost:9021"
echo "🔧 Flink Job Manager: http://localhost:9081"
echo ""
echo "⏳ Waiting for Confluent Control Center to be ready..."

# Wait for Control Center to be available
MAX_WAIT=120
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:9021 | grep -q "200"; then
        echo "✅ Control Center is ready!"
        break
    fi
    echo -n "."
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo ""
    echo "⚠️  Warning: Control Center did not respond within ${MAX_WAIT} seconds."
    echo "Continuing anyway, but services may not be fully ready."
fi

# Step 2: Start the Fraud Detection Web Application
echo ""
echo "🚀 Step 2: Starting Fraud Detection Web Application..."
echo ""

# Activate virtual environment and start the app
source .venv/bin/activate
cd src

echo "Starting web application with 250 dummy records..."
echo ""
echo "The application will be available at: http://localhost:8888"
echo ""

# Open browser tabs
echo "🌐 Opening browser tabs..."
sleep 2

# Open Confluent Control Center
open_browser "http://localhost:9021" &

# Open Flink Job Manager
open_browser "http://localhost:9081" &

echo ""
echo "Press CTRL-C to stop the application"
echo ""

# Open Fraud Detection App
open_browser "http://localhost:8888" &

python3 app.py --config ./config/docker.yml --users --dummy 250
