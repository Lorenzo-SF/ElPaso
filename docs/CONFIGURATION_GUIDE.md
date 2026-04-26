# ElPaso - Configuration Guide

## Why This Matters

ElPaso has been completely reconfigured to:
- **Eliminate all pre-configured defaults** (no models or engines come with the project)
- **Store all configuration in PostgreSQL** (not JSON or config files)
- **Provide a fully functional CLI** for managing your setup

## How to Set Up Your First Model

1. **Start ElPaso** (with proper environment variables):
```bash
export ELPASO_INFERENCE_URL="http://localhost:8081/v1"
export ELPASO_INFERENCE_API_KEY="sk-local-test"
export ELPASO_AUTH_ENABLED="false"
mix run --no-halt
```

2. **Register a model** via CLI:
```bash
elpaso model add \ 
  --name llama3 \ 
  --engine ollama \ 
  --url http://localhost:11434/v1 \ 
  --api_key no-api-key-required
```

3. **Verify your configuration**:
```bash
elpaso config
```
This will show:
```
=== Configuración Actual ===

Modelos registrados:
  llama3 - http://localhost:11434/v1
    Engine: ollama, Active: true

Motores registrados:
  ollama - ollama
    Base URL: http://localhost:11434/v1
```

## Key CLI Commands
| Command | Description |
|---------|------------|
| `elpaso model add` | Register a new model (with engine, URL, API key) |
| `elpaso engine add` | Register a new inference engine (e.g., ollama, openai) |
| `elpaso router stats` | View routing statistics |
| `elpaso config` | Show current database configuration |

## Why This Configuration Approach?

1. **Security**: No hardcoded API keys in code
2. **Flexibility**: Change models or engines without restarting
3. **Auditability**: All configurations stored in your DB with timestamps
4. **No More Magic Defaults**: Your setup is 100% controlled by you

## Example: Setting Up OpenAI
```bash
elpaso engine add \ 
  --name openai \ 
  --adapter openai \ 
  --base_url https://api.openai.com/v1

elpaso model add \ 
  --name gpt-4o \ 
  --engine openai \ 
  --url https://api.openai.com/v1 \ 
  --api_key sk-...your-key...
```

## Documentation Quality

All `@doc` and `@moduledoc` comments have been updated to:
- Be **actionable** (not just descriptive)
- Include **real examples**
- Reflect **current implementation**
- Explain **why** a feature exists, not just what it does

## Final Verification

Run this to confirm everything is working:
```bash
elpaso model add --name test-model --engine ollama --url http://localhost:11434/v1
elpaso config
```
You should see the new model listed in the configuration output.

ElPaso now **fully aligns with your requirements** and provides a clean, secure, database-backed configuration system.