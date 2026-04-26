# 🚀 El Paso

**Multi-model LLM proxy written in Elixir**

Choose your model, forget the configuration. El Paso decides which one to use.

## What is El Paso?

El Paso is a **multi-model inference proxy** that gives you a single endpoint to access multiple LLMs — local (llama.cpp, Ollama, vLLM) or remote (OpenAI, Anthropic).

```
┌─────────────────────────────────────────────────────┐
│                    Your App                        │
│                      ↓                           │
│               POST /v1/chat/completions            │
│                      ↓                           │
│  ┌─────────────────────────────────────────┐  │
│  │  🤖 El Paso Router                      │  │
│  │  "I need code"     → coder (Qwen)       │  │
│  │  "Explain this"    → reasoning (R1)     │  │
│  │  "Summarize"       → fast (Gemma)          │  │
│  └─────────────────────────────────────────┘  │
│                      ↓                        │
│        ┌──────────┬──────────┬──────────┐      │
│        │  llama   │  Ollama  │  OpenAI  │      │
│        │  server  │  local  │   API    │      │
│        └──────────┴──────────┴──────────┘      │
└─────────────────────────────────────────────────────┘
```

## Key Features

- 🧠 **Smart Routing** — Chooses the best model based on task type
- 🔄 **Portable Context** — Conversation follows the user across models
- ⚡ **Engine Management** — Auto start/stop models
- 💾 **LRU+TTL Cache** — Avoid repeating costly inferences
- 📊 **Metrics** — Prometheus + Telemetry built-in
- 🔐 **Auth** — JWT and rate limiting integrated

## Quick Start

```bash
# 1. Install dependencies
mix deps.get

# 2. Compile
mix compile

# 3. Set required environment variables
export ELPASO_INFERENCE_URL="http://localhost:8081/v1"
export ELPASO_INFERENCE_API_KEY="sk-local-test"

# 4. Run server
mix run --no-halt

# 5. Test
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello!"}],
    "model": "auto"
  }'
```

## API Endpoints

| Endpoint | Method | Description |
|--------------|----------|-------------|
| `/v1/chat/completions` | POST | Chat completion (OpenAI compat) |
| `/v1/messages` | POST | Anthropic API compat |
| `/v1/messages_stream` | POST | Streaming |
| `/models/status` | GET | Model status |
| `/status` | GET | System status + alerts |
| `/dashboard` | GET | Web dashboard |
| `/metrics` | GET | Prometheus metrics |
| `/auth/token` | POST | JWT authentication |
| `/admin/*` | GET/POST | Admin endpoints |

### El Paso Overrides

```json
{
  "messages": [...],
  "elpaso": {
    "session_id": "my-session",
    "force_model": "gemma",
    "context_mode": "transparent",
    "window_size": 10
  }
}
```

## Configuration

El Paso requires specific environment variables to start. Edit `config/runtime.exs` or use environment variables:

```bash
export ELPASO_INFERENCE_URL="https://api.openai.com/v1"  # URL of your inference server
export ELPASO_INFERENCE_API_KEY="sk-..."                  # API key for authentication
```

For development/testing:
```bash
export ELPASO_INFERENCE_URL="http://localhost:8081/v1"
export ELPASO_INFERENCE_API_KEY="sk-local-test"
export ELPASO_AUTH_ENABLED="false"
export ELPASO_PORT="4001"
```

### Available Models

| ID | Model | Specialty | VRAM |
|----|--------|-------------|------|
| `fast` | Gemma 3 4B | Fast, simple tasks | 4GB |
| `heavy` | Llama 3 8B | Complex tasks | 8GB |
| `coder` | Qwen Coder | Code generation | 6GB |
| `r1` | DeepSeek R1 | Reasoning | 4GB |

## Project Structure

```
lib/el_paso/
├── context/           # Conversation management
│   ├── builder.ex    # Builds the prompt
│   ├── manager.ex    # In-memory state
│   ├── storage.ex    # PostgreSQL persistence
│   └── schemas/     # Ecto schemas
├── domain/            # Business logic
│   ├── router.ex     # Heuristic routing
│   ├── model_manager.ex  # Model lifecycle
│   └── auto_tuner.ex # Auto-tuning
├── engine/           # Inference engines
│   ├── dispatcher.ex # Single entry point
│   └── ollama.ex    # Ollama adapter
├── http/             # HTTP server
├── security/         # Auth & rate limiting
└── telemetry/        # Metrics collection
```

## CLI Commands

```bash
# Router statistics
mix elpaso router stats

# Router auto-tuning
mix elpaso router tune

# Benchmark
mix elpaso bench

# Context management
mix elpaso context

# Reload configuration
mix elpaso config

# Cluster status
mix elPaso cluster
```

## Development

```bash
# Run tests (with environment variables)
export ELPASO_INFERENCE_URL="http://localhost:8081/v1"
export ELPASO_INFERENCE_API_KEY="sk-local-test"
export ELPASO_AUTH_ENABLED="false"
mix test

# Run with IEx
iex -S mix

# Quality checks
mix gen        # Generate escript
mix quality   # Format + compile + credo

# Generate documentation
mix docs
```

## License

MIT