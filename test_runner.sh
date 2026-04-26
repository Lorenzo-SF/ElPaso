#!/bin/bash
# Test runner for ElPaso with proper environment setup

echo "=== ElPaso Test Runner ==="

# Set required environment variables for tests and production
export ELPASO_INFERENCE_URL="http://localhost:8081/v1"
export ELPASO_INFERENCE_API_KEY="sk-local-test" 
export ELPASO_AUTH_ENABLED="false"
export ELPASO_PORT="4001"
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_USER="postgres"
export DB_PASSWORD="postgres"
export DB_NAME="elpaso_test"

echo "Environment configured for testing..."

# Run the tests
echo "Running all tests..."
mix test 2>&1 | tail -10

echo "Test execution completed."