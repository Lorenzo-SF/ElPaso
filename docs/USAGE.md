# ElPaso Usage Guide

Complete guide for installing, configuring, and using ElPaso.

---

## Table of Contents

1. [Installation](#installation)
2. [Database Setup](#database-setup)
3. [Configuration](#configuration)
4. [CLI](#cli)
   - [Engine Management](#engine-management)
   - [Model Management](#model-management)
   - [Router Analytics](#router-analytics)
   - [Benchmarking](#benchmarking)
5. [API](#api)
   - [Authentication](#authentication)
   - [Chat Completions](#chat-completions)
   - [Anthropic Messages](#anthropic-messages)
   - [Admin Endpoints](#admin-endpoints)
6. [Architecture Overview](#architecture-overview)

---

## Installation

```bash
git clone https://github.com/Lorenzo-SF/ElPaso.git
cd ElPaso
mix deps.get
mix compile
```

Requirements:
- Elixir 1.19.5+
- Erlang/OTP 28+
- PostgreSQL 14+

---

## Database Setup

```bash
# Create database
export DATABASE_URL="postgresql://postgres:postgres@localhost/elpaso"
mix ecto.create
mix ecto.migrate

# For tests
export DATABASE_URL="postgresql://postgres:postgres@localhost/elpaso_test"
mix ecto.create
mix ecto.migrate
```

---

## Configuration

ElPaso uses an INI-style configuration file at `~/.config/elpaso/elpaso.conf`:

```ini
[inference]
url = http://localhost:8081/v1
api_key = sk-local-test

[auth]
enabled = true
allow_anonymous = false

[routing]
auto_tune = true
auto_tune_min_confidence = 0.85
auto_tune_min_decisions = 50
auto_tune_check_interval_hours = 24

[cost_management]
enabled = true
daily_usd = 100.0
alert_at_pct = 80

[cluster]
enabled = false
node_name = node1@localhost
role = both
discovery = static
```

You can also use environment variables:

```bash
export ELPASO_INFERENCE_URL="https://api.openai.com/v1"
export ELPASO_INFERENCE_API_KEY="sk-..."
export ELPASO_AUTH_ENABLED="true"
export ELPASO_ALLOW_ANONYMOUS="false"
export ELPASO_COST_ENABLED="true"
export ELPASO_DAILY_LIMIT="100.0"
```

---

## CLI

### Engine Management

Engines are inference backends (Ollama, OpenAI, Anthropic, llama.cpp):

```bash
# Add an engine
mix elpaso.engine.add \
  --name ollama-local \
  --adapter ollama \
  --base-url http://localhost:11434

# Remove an engine
mix elpaso.engine.remove --name ollama-local

# List engines
mix elpaso.engine.list
```

Supported adapters: `ollama`, `openai`, `anthropic`, `llama`, `openai_compatible`.

### Model Management

```bash
# Add a model linked to an engine
mix elpaso.model.add \
  --name llama3 \
  --engine ollama-local \
  --url http://localhost:11434/v1

# List models
mix elpaso.model.list

# Activate/deactivate
mix elpaso.model.start --name llama3
mix elpaso.model.stop --name llama3
```

### Router Analytics

```bash
# Show routing statistics
mix elpaso.router.stats

# Run auto-tuning manually
mix elpaso.router.tune
```

### Benchmarking

```bash
# Run throughput benchmark
mix elpaso.bench.run
```

### Admin

```bash
# List active sessions
mix elpaso.admin.sessions
```

---

## API

Start the server:

```bash
mix elpaso.server.start
# → http://localhost:8080
```

### Authentication

Get a JWT token:

```bash
curl -X POST http://localhost:8080/auth/token \
  -H "Content-Type: application/json" \
  -d '{"api_key": "your-api-key"}'
```

Use the token in subsequent requests:

```bash
curl -H "Authorization: Bearer <token>" ...
```

### Chat Completions

OpenAI-compatible endpoint:

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "model": "auto",
    "messages": [
      {"role": "user", "content": "Explain quantum computing in simple terms"}
    ]
  }'
```

Use `"model": "auto"` to let the router select the best model based on task classification.

### Anthropic Messages

Anthropic-compatible endpoint:

```bash
curl -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "model": "auto",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'
```

### Admin Endpoints

```bash
# List models
curl http://localhost:8080/v1/models

# Health check
curl http://localhost:8080/health

# Prometheus metrics
curl http://localhost:8080/metrics

# Web dashboard
curl http://localhost:8080/dashboard

# Admin sessions (requires auth)
curl -H "Authorization: Bearer <token>" http://localhost:8080/admin/sessions
```

---

## Architecture Overview

| Layer | Responsibility | Key Modules |
|-------|---------------|-------------|
| **HTTP** | API, dashboard, metrics | `ElPaso.HTTP.Server`, `ElPaso.HTTP.Dashboard` |
| **Router** | Task classification, model selection | `ElPaso.Domain.Router`, `ElPaso.Domain.RouterAnalyzer` |
| **Engine** | Adapter abstraction | `ElPaso.Engine.Adapter`, `ElPaso.Engine.Dispatcher` |
| **Context** | Session storage, messages | `ElPaso.Context.Storage`, `ElPaso.Context.Schemas` |
| **Config** | INI config with ETS cache | `ElPaso.Config.Loader` |

The router classifies requests by task type:

| Task Type | Description | Typical Model |
|-----------|-------------|---------------|
| `code` | Programming, debugging | Qwen, DeepSeek-Coder |
| `reasoning` | Logic, math, explanation | R1, o1 |
| `summarization` | Text summarization | Gemma, Haiku |
| `creative` | Writing, brainstorming | GPT-4, Claude |
| `translation` | Language translation | NLLB, Aya |
| `question_answer` | Factual Q&A | Any general model |

The `RouterAnalyzer` tracks success rates and retry percentages per `(model, task)` combination, generating alerts when performance degrades. `AutoTuner` periodically adjusts affinity scores based on these analytics.
