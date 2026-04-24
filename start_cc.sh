#!/bin/bash

# Start Confluent Cloud Demo - Fraud Detection
# This script provisions Confluent Cloud resources using Terraform and starts the web application

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
echo "Starting Confluent Cloud Fraud Detection Demo"
echo "=========================================="
echo ""

# Check if .env file exists
if [ ! -f "./terraform/.env" ]; then
    echo "❌ Error: ./terraform/.env file not found!"
    echo ""
    echo "Please create the .env file with your Confluent Cloud API credentials:"
    echo ""
    echo "cat > ./terraform/.env <<EOF"
    echo "#!/bin/bash"
    echo "export CONFLUENT_CLOUD_API_KEY=\"<YOUR_CONFLUENT_CLOUD_API_KEY_HERE>\""
    echo "export CONFLUENT_CLOUD_API_SECRET=\"<YOUR_CONFLUENT_CLOUD_API_SECRET_HERE>\""
    echo "EOF"
    echo ""
    exit 1
fi

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

# Step 1: Provision Confluent Cloud resources
echo "📦 Step 1: Provisioning Confluent Cloud resources with Terraform..."
echo ""
cd terraform

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..."
    terraform init
fi

# Source environment variables
source .env

# Apply Terraform configuration
echo "Applying Terraform configuration..."
terraform plan
terraform apply --auto-approve

# Export Terraform outputs
echo "Exporting Terraform outputs..."
terraform output -json > tf_aws_data.json

# Generate configuration file
echo "Generating configuration file..."
./set_config.sh

cd ..

echo ""
echo "✅ Confluent Cloud resources provisioned successfully!"
echo ""

# Step 2: Start the Fraud Detection Web Application
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

# Open Confluent Cloud Console
open_browser "https://confluent.cloud/login" &

echo ""
echo "Press CTRL-C to stop the application"
echo ""

# Open Fraud Detection App
open_browser "http://localhost:8888" &

python3 app.py --config ./config/tf_config.yml --users --dummy 250
