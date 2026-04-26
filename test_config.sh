# Test configuration for elpaso
# This file should be loaded in test environment only

# For testing, we can set dummy values that won't be used during tests
# But we need to avoid the config validation errors

# Mock inference URL and key for tests (these won't be used in unit tests)
export ELPASO_INFERENCE_URL="http://localhost:8081/v1"
export ELPASO_INFERENCE_API_KEY="sk-local-test"
export ELPASO_AUTH_ENABLED="false"
export ELPASO_PORT="4001"

# Database for tests
export DB_HOST="localhost" 
export DB_PORT="5432"
export DB_USER="postgres"
export DB_PASSWORD="postgres"
export DB_NAME="elpaso_test"