# ElPaso

[![License](https://img.shields.io/github/license/Lorenzo-SF/ElPaso)](https://github.com/Lorenzo-SF/ElPaso/blob/main/LICENSE)
[![CI](https://github.com/Lorenzo-SF/ElPaso/actions/workflows/ci.yml/badge.svg)](https://github.com/Lorenzo-SF/ElPaso/actions)
[![Coverage](https://img.shields.io/badge/coverage-73.97%25-success)](https://github.com/Lorenzo-SF/ElPaso/actions)
[![Dialyzer](https://img.shields.io/badge/dialyzer-passing-success)]()

> **Multi-model LLM proxy for Elixir.** A unified gateway to local and remote inference engines with smart routing, session management, and OpenAI-compatible API.

---

## What is ElPaso?

ElPaso is an inference proxy that sits between your application and multiple LLM providers — local (llama.cpp, Ollama, vLLM) or remote (OpenAI, Anthropic) — exposing a single OpenAI-compatible endpoint.

```
┌─────────────────────────────────────────────────────┐
│                   Your Application                  │
│              POST /v1/chat/completions              │
│                      ↓                              │
│  ┌─────────────────────────────────────────────┐    │
│  │         🤖 ElPaso Router                     │    │
│  │         "Need code" → coder (Qwen)           │    │
│  │         "Explain" → reasoning (R1)           │    │
│  │         "Summarize" → fast (Gemma)           │    │
│  └─────────────────────────────────────────────┘    │
│                      ↓                              │
│        ┌──────────┬──────────┬───────────┐         │
│        │  llama   │  Ollama  │  OpenAI   │         │
│        │ server   │  local   │    API    │         │
│        └──────────┴──────────┴───────────┘         │
└─────────────────────────────────────────────────────┘
```

---

## Requirements

- **Elixir**: 1.19.5+
- **OTP**: 28+
- **PostgreSQL**: 14+ (for session persistence)
- Linux / macOS / WSL2

---

## Installation

```bash
git clone https://github.com/Lorenzo-SF/ElPaso.git
cd ElPaso
mix deps.get
mix compile
```

Set up the database:

```bash
export DATABASE_URL="postgresql://user:password@localhost/elpaso"
mix ecto.create
mix ecto.migrate
```

---

## Quick Start

```bash
# Start the server
elpaso server start
# → http://localhost:8080

# Add an engine
mix elpaso engine add \
  --name ollama-local \
  --adapter ollama \
  --base-url http://localhost:11434

# Add a model
mix elpaso model add \
  --name llama3 \
  --engine ollama-local \
  --url http://localhost:11434/v1

# Query
 curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Hello!"}], "model": "auto"}'
```

---

## Architecture

ElPaso is built on a layered architecture:

| Layer | Responsibility | Key Modules |
|-------|---------------|-------------|
| **HTTP** | OpenAI-compatible API, dashboard, metrics | `ElPaso.HTTP.Server`, `ElPaso.HTTP.Dashboard` |
| **Router** | Task classification, model selection, fallback | `ElPaso.Domain.Router`, `ElPaso.Domain.RouterAnalyzer` |
| **Engine** | Adapter abstraction for Ollama, OpenAI, Anthropic, llama.cpp | `ElPaso.Engine.Adapter`, `ElPaso.Engine.Dispatcher` |
| **Context** | Session storage, messages, conversation summaries | `ElPaso.Context.Storage`, `ElPaso.Context.Schemas` |
| **Config** | INI-based configuration with ETS affinity cache | `ElPaso.Config.Loader` |

The project uses [Zaguan](https://github.com/Lorenzo-SF/zaguan) for TUI/CLI visual components and circuit breaker fault tolerance.

---

## Key Features

- **Single API** — OpenAI-compatible endpoint for all models
- **Smart Routing** — Route by task type (code, reasoning, fast)
- **Session Context** — Portable conversation history across models
- **Engine Management** — Register and manage inference backends
- **Auto-Tuning** — Periodic affinity adjustment based on routing analytics
- **Cost Management** — Daily budget tracking and per-model pricing
- **Telemetry** — Prometheus metrics built-in
- **Cluster Mode** — Automatic node discovery with libcluster
- **Security** — API key auth, JWT tokens, rate limiting, security headers

---

## CLI

```bash
# Engine management
mix elpaso.engine.add --name ollama-local --adapter ollama --base-url http://localhost:11434
mix elpaso.engine.remove --name ollama-local

# Model management
mix elpaso.model.add --name llama3 --engine ollama-local --url http://localhost:11434/v1
mix elpaso.model.list

# Router analytics
mix elpaso.router.stats
mix elpaso.router.tune

# Benchmarking
mix elpaso.bench.run

# Admin
mix elpaso.admin.sessions
```

---

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/chat/completions` | POST | Chat completion (OpenAI compatible) |
| `/v1/messages` | POST | Anthropic-compatible messages endpoint |
| `/v1/models` | GET | List available models |
| `/auth/token` | POST | JWT token generation |
| `/health` | GET | Health check |
| `/metrics` | GET | Prometheus metrics |
| `/dashboard` | GET | Web dashboard |
| `/admin/sessions` | GET | Admin session listing |

---

## Documentation

- [README_ES.md](README_ES.md) — Spanish version
- [CHANGELOG.md](CHANGELOG.md) — Release notes

---

## Development

```bash
# Database setup
export DATABASE_URL="postgresql://postgres:postgres@localhost/elpaso_test"
mix ecto.create
mix ecto.migrate

# Testing (threshold: 70%)
mix test
mix test --cover

# Quality
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
mix dialyzer
```

---

## License

MIT. See [LICENSE](LICENSE).
