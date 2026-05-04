# ElPaso

[![License](https://img.shields.io/github/license/Lorenzo-SF/ElPaso)](https://github.com/Lorenzo-SF/ElPaso/blob/main/LICENSE)
[![CI](https://github.com/Lorenzo-SF/ElPaso/actions/workflows/ci.yml/badge.svg)](https://github.com/Lorenzo-SF/ElPaso/actions)

> **Proxy multi-modelo LLM para Elixir.** Un gateway unificado para motores de inferencia locales y remotos con routing inteligente, gestión de sesiones y API compatible con OpenAI.

---

## ¿Qué es ElPaso?

ElPaso es un proxy de inferencia que se sitúa entre tu aplicación y múltiples proveedores de LLM — locales (llama.cpp, Ollama, vLLM) o remotos (OpenAI, Anthropic) — exponiendo un único endpoint compatible con OpenAI.

```
┌─────────────────────────────────────────────────────┐
│                   Tu Aplicación                     │
│              POST /v1/chat/completions              │
│                      ↓                              │
│  ┌─────────────────────────────────────────────┐    │
│  │         🤖 ElPaso Router                     │    │
│  │         "Necesito código" → coder (Qwen)     │    │
│  │         "Explícame" → reasoning (R1)         │    │
│  │         "Resume" → fast (Gemma)              │    │
│  └─────────────────────────────────────────────┘    │
│                      ↓                              │
│        ┌──────────┬──────────┬───────────┐         │
│        │  llama   │  Ollama  │  OpenAI   │         │
│        │ server   │  local   │    API    │         │
│        └──────────┴──────────┴───────────┘         │
└─────────────────────────────────────────────────────┘
```

---

## Requisitos

- **Elixir**: 1.19.5+
- **OTP**: 28+
- **PostgreSQL**: 14+ (para persistencia de sesiones)
- Linux / macOS / WSL2

---

## Instalación

```bash
git clone https://github.com/Lorenzo-SF/ElPaso.git
cd ElPaso
mix deps.get
mix compile
```

Configurar la base de datos:

```bash
export DATABASE_URL="postgresql://user:password@localhost/elpaso"
mix ecto.create
mix ecto.migrate
```

---

## Inicio Rápido

```bash
# Iniciar el servidor
elpaso server start
# → http://localhost:8080

# Añadir un motor
mix elpaso engine add \
  --name ollama-local \
  --adapter ollama \
  --base-url http://localhost:11434

# Añadir un modelo
mix elpaso model add \
  --name llama3 \
  --engine ollama-local \
  --url http://localhost:11434/v1

# Consultar
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Hola!"}], "model": "auto"}'
```

---

## Características Principales

- **API Única** — Endpoint compatible con OpenAI para todos los modelos
- **Routing Inteligente** — Ruta por tipo de tarea (código, razonamiento, rápido)
- **Contexto de Sesión** — Historial de conversación portable entre modelos
- **Gestión de Motores** — Registra y gestiona backends de inferencia
- **Telemetría** — Métricas Prometheus integradas
- **Modo Cluster** — Descubrimiento automático de nodos con libcluster

---

## CLI

```bash
mix elpaso engine add --name <nombre> --adapter <adapter> --base-url <url>
mix elpaso model add --name <nombre> --engine <motor> --url <url>
mix elpaso router stats
mix elpaso router tune
mix elpaso bench run
```

---

## Endpoints de la API

| Endpoint | Método | Descripción |
|----------|--------|-------------|
| `/v1/chat/completions` | POST | Chat completion (compatible OpenAI) |
| `/v1/models` | GET | Listar modelos disponibles |
| `/health` | GET | Health check |
| `/metrics` | GET | Métricas Prometheus |

---

## Documentación

- [README.md](README.md) — Versión en inglés

---

## Desarrollo

```bash
# Tests
export DATABASE_URL="postgresql://user:password@localhost/elpaso_test"
mix test

# Calidad
mix format
mix credo --strict
mix dialyzer
```

---

## Licencia

MIT. Ver [LICENSE](LICENSE).
