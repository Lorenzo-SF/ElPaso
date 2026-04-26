#!/bin/bash
# ElPaso Production Startup Script

echo "=== ElPaso Production Startup ==="

# Check if we're in production mode
if [ "$MIX_ENV" = "prod" ]; then
    echo "Running in PRODUCTION mode"
    
    # Set required environment variables for production
    export ELPASO_INFERENCE_URL="${ELPASO_INFERENCE_URL:-http://localhost:8081/v1}"
    export ELPASO_INFERENCE_API_KEY="${ELPASO_INFERENCE_API_KEY:-sk-local-test}" 
    export ELPASO_AUTH_ENABLED="${ELPASO_AUTH_ENABLED:-false}"
    export ELPASO_PORT="${ELPASO_PORT:-8080}"
    
    # Validate required configuration
    if [ -z "$ELPASO_INFERENCE_URL" ] || [ -z "$ELPASO_INFERENCE_API_KEY" ]; then
        echo "❌ ERROR: Missing required environment variables for production mode"
        echo "Please set:"
        echo "  ELPASO_INFERENCE_URL - URL of inference server"
        echo "  ELPASO_INFERENCE_API_KEY - API key for authentication"
        exit 1
    fi
    
    echo "✅ Production configuration validated"
else
    # Development/test mode - use default values
    export ELPASO_INFERENCE_URL="http://localhost:8081/v1"
    export ELPASO_INFERENCE_API_KEY="sk-local-test" 
    export ELPASO_AUTH_ENABLED="false"
    export ELPASO_PORT="4001"
    echo "✅ Development/test configuration set"
fi

echo "Starting ElPaso application..."
exec elpaso