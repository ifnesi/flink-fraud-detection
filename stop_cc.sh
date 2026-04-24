#!/bin/bash

# Stop Confluent Cloud Demo - Fraud Detection
# This script destroys all Confluent Cloud resources provisioned by Terraform

set -e

echo "=========================================="
echo "Stopping Confluent Cloud Fraud Detection Demo"
echo "=========================================="
echo ""

# Check if terraform directory exists
if [ ! -d "terraform" ]; then
    echo "❌ Error: terraform directory not found!"
    echo ""
    exit 1
fi

# Check if .env file exists
if [ ! -f "./terraform/.env" ]; then
    echo "❌ Error: ./terraform/.env file not found!"
    echo ""
    echo "Cannot proceed without Confluent Cloud API credentials."
    echo ""
    exit 1
fi

# Deactivate virtual environment if active
if [[ "$VIRTUAL_ENV" != "" ]]; then
    echo "Deactivating Python virtual environment..."
    deactivate
fi

# Destroy Confluent Cloud resources
echo "🗑️  Destroying Confluent Cloud resources with Terraform..."
echo ""
cd terraform

# Source environment variables
source .env

# Destroy resources
terraform destroy --auto-approve

cd ..

echo ""
echo "✅ All Confluent Cloud resources have been destroyed successfully!"
echo ""
echo "💡 Note: This helps avoid incurring costs for unused resources."
echo ""
