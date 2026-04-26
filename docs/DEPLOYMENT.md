# ElPaso Configuration and Deployment Guide

## Running ElPaso with Required Environment Variables

To successfully run ElPaso, you must provide the required environment variables. This is especially important for production mode.

### Required Environment Variables

```bash
export ELPASO_INFERENCE_URL="https://api.openai.com/v1"  # URL of your inference server
export ELPASO_INFERENCE_API_KEY="sk-..."                  # API key for authentication
```

### Example Configurations

**For OpenAI:**
```bash
export ELPASO_INFERENCE_URL="https://api.openai.com/v1"
export ELPASO_INFERENCE_API_KEY="sk-your-api-key-here"
```

**For Ollama local:**
```bash
export ELPASO_INFERENCE_URL="http://localhost:11434/v1"
export ELPASO_INFERENCE_API_KEY="no-api-key-required"
```

**For development/testing (if you want to avoid setting env vars):**
```bash
export ELPASO_INFERENCE_URL="http://localhost:8081/v1"
export ELPASO_INFERENCE_API_KEY="sk-local-test"
export ELPASO_AUTH_ENABLED="false"
export ELPASO_PORT="4001"
```

## Running in Production Mode

In production mode (`MIX_ENV=prod`), all configuration must be provided through environment variables:

```bash
MIX_ENV=prod elpaso
```

Or with full environment:
```bash
export ELPASO_INFERENCE_URL="http://localhost:8081/v1"
export ELPASO_INFERENCE_API_KEY="sk-local-test"
export ELPASO_AUTH_ENABLED="false"
export ELPASO_PORT="8080"

MIX_ENV=prod elpaso
```

## Running Tests

To run tests, set the environment variables:
```bash
export ELPASO_INFERENCE_URL="http://localhost:8081/v1"
export ELPASO_INFERENCE_API_KEY="sk-local-test"
export ELPASO_AUTH_ENABLED="false"
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_USER="postgres"
export DB_PASSWORD="postgres"
export DB_NAME="elpaso_test"

mix test
```

## Testing with Script

You can also use the included script:
```bash
./test_runner.sh  # For running tests with proper env vars
```

This configuration approach ensures that ElPaso can start properly in both development and production environments.