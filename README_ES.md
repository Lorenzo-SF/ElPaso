# ElPaso

[![License](https://img.shields.io/github/license/Lorenzo-SF/ElPaso)](https://github.com/Lorenzo-SF/ElPaso/blob/main/LICENSE)
[![CI](https://github.com/Lorenzo-SF/ElPaso/actions/workflows/ci.yml/badge.svg)](https://github.com/Lorenzo-SF/ElPaso/actions)
[![Cobertura](https://img.shields.io/badge/cobertura-73.97%25-success)](https://github.com/Lorenzo-SF/ElPaso/actions)
[![Dialyzer](https://img.shields.io/badge/dialyzer-passing-success)]()

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

## Arquitectura

ElPaso se construye sobre una arquitectura por capas:

| Capa | Responsabilidad | Módulos Clave |
|------|----------------|---------------|
| **HTTP** | API compatible OpenAI, dashboard, métricas | `ElPaso.HTTP.Server`, `ElPaso.HTTP.Dashboard` |
| **Router** | Clasificación de tareas, selección de modelo, fallback | `ElPaso.Domain.Router`, `ElPaso.Domain.RouterAnalyzer` |
| **Engine** | Abstracción de adaptadores para Ollama, OpenAI, Anthropic, llama.cpp | `ElPaso.Engine.Adapter`, `ElPaso.Engine.Dispatcher` |
| **Contexto** | Almacenamiento de sesiones, mensajes, resúmenes de conversación | `ElPaso.Context.Storage`, `ElPaso.Context.Schemas` |
| **Config** | Configuración INI con caché de afinidad en ETS | `ElPaso.Config.Loader` |

El proyecto utiliza [Zaguan](https://github.com/Lorenzo-SF/zaguan) para componentes visuales TUI/CLI y tolerancia a fallos mediante circuit breakers.

---

## Características Principales

- **API Única** — Endpoint compatible con OpenAI para todos los modelos
- **Routing Inteligente** — Ruta por tipo de tarea (código, razonamiento, rápido)
- **Contexto de Sesión** — Historial de conversación portable entre modelos
- **Gestión de Motores** — Registra y gestiona backends de inferencia
- **Auto-Tuning** — Ajuste periódico de afinidades basado en análisis de routing
- **Gestión de Costes** — Seguimiento de presupuesto diario y precios por modelo
- **Telemetría** — Métricas Prometheus integradas
- **Modo Cluster** — Descubrimiento automático de nodos con libcluster
- **Seguridad** — Autenticación por API key, tokens JWT, rate limiting, headers de seguridad

---

## CLI

```bash
# Gestión de motores
mix elpaso.engine.add --name ollama-local --adapter ollama --base-url http://localhost:11434
mix elpaso.engine.remove --name ollama-local

# Gestión de modelos
mix elpaso.model.add --name llama3 --engine ollama-local --url http://localhost:11434/v1
mix elpaso.model.list

# Análisis del router
mix elpaso.router.stats
mix elpaso.router.tune

# Benchmarking
mix elpaso.bench.run

# Administración
mix elpaso.admin.sessions
```

---

## Endpoints de la API

| Endpoint | Método | Descripción |
|----------|--------|-------------|
| `/v1/chat/completions` | POST | Chat completion (compatible OpenAI) |
| `/v1/messages` | POST | Endpoint de mensajes compatible Anthropic |
| `/v1/models` | GET | Listar modelos disponibles |
| `/auth/token` | POST | Generación de token JWT |
| `/health` | GET | Health check |
| `/metrics` | GET | Métricas Prometheus |
| `/dashboard` | GET | Dashboard web |
| `/admin/sessions` | GET | Listado de sesiones para admin |

---

## Documentación

- [README.md](README.md) — Versión en inglés
- [CHANGELOG.md](CHANGELOG.md) — Notas de versión

---

## Desarrollo

```bash
# Configuración de la base de datos
export DATABASE_URL="postgresql://postgres:postgres@localhost/elpaso_test"
mix ecto.create
mix ecto.migrate

# Tests (umbral: 70%)
mix test
mix test --cover

# Calidad
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
mix dialyzer
```

---

## Licencia

MIT. Ver [LICENSE](LICENSE).
