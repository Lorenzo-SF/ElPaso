# Guía de Uso de ElPaso

Guía completa para instalar, configurar y usar ElPaso.

---

## Índice

1. [Instalación](#instalación)
2. [Configuración de Base de Datos](#configuración-de-base-de-datos)
3. [Configuración](#configuración)
4. [CLI](#cli)
   - [Gestión de Motores](#gestión-de-motores)
   - [Gestión de Modelos](#gestión-de-modelos)
   - [Análisis del Router](#análisis-del-router)
   - [Benchmarking](#benchmarking)
5. [API](#api)
   - [Autenticación](#autenticación)
   - [Chat Completions](#chat-completions)
   - [Mensajes Anthropic](#mensajes-anthropic)
   - [Endpoints de Admin](#endpoints-de-admin)
6. [Visión de Arquitectura](#visión-de-arquitectura)

---

## Instalación

```bash
git clone https://github.com/Lorenzo-SF/ElPaso.git
cd ElPaso
mix deps.get
mix compile
```

Requisitos:
- Elixir 1.19.5+
- Erlang/OTP 28+
- PostgreSQL 14+

---

## Configuración de Base de Datos

```bash
# Crear base de datos
export DATABASE_URL="postgresql://postgres:postgres@localhost/elpaso"
mix ecto.create
mix ecto.migrate

# Para tests
export DATABASE_URL="postgresql://postgres:postgres@localhost/elpaso_test"
mix ecto.create
mix ecto.migrate
```

---

## Configuración

ElPaso utiliza un archivo de configuración estilo INI en `~/.config/elpaso/elpaso.conf`:

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

También puedes usar variables de entorno:

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

### Gestión de Motores

Los motores son backends de inferencia (Ollama, OpenAI, Anthropic, llama.cpp):

```bash
# Añadir un motor
mix elpaso.engine.add \
  --name ollama-local \
  --adapter ollama \
  --base-url http://localhost:11434

# Eliminar un motor
mix elpaso.engine.remove --name ollama-local

# Listar motores
mix elpaso.engine.list
```

Adaptadores soportados: `ollama`, `openai`, `anthropic`, `llama`, `openai_compatible`.

### Gestión de Modelos

```bash
# Añadir un modelo vinculado a un motor
mix elpaso.model.add \
  --name llama3 \
  --engine ollama-local \
  --url http://localhost:11434/v1

# Listar modelos
mix elpaso.model.list

# Activar/desactivar
mix elpaso.model.start --name llama3
mix elpaso.model.stop --name llama3
```

### Análisis del Router

```bash
# Mostrar estadísticas de routing
mix elpaso.router.stats

# Ejecutar auto-tuning manualmente
mix elpaso.router.tune
```

### Benchmarking

```bash
# Ejecutar benchmark de rendimiento
mix elpaso.bench.run
```

### Administración

```bash
# Listar sesiones activas
mix elpaso.admin.sessions
```

---

## API

Iniciar el servidor:

```bash
mix elpaso.server.start
# → http://localhost:8080
```

### Autenticación

Obtener un token JWT:

```bash
curl -X POST http://localhost:8080/auth/token \
  -H "Content-Type: application/json" \
  -d '{"api_key": "tu-api-key"}'
```

Usar el token en peticiones posteriores:

```bash
curl -H "Authorization: Bearer <token>" ...
```

### Chat Completions

Endpoint compatible con OpenAI:

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "model": "auto",
    "messages": [
      {"role": "user", "content": "Explica la computación cuántica en términos simples"}
    ]
  }'
```

Usa `"model": "auto"` para dejar que el router seleccione el mejor modelo basado en la clasificación de tarea.

### Mensajes Anthropic

Endpoint compatible con Anthropic:

```bash
curl -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "model": "auto",
    "messages": [
      {"role": "user", "content": "Hola!"}
    ]
  }'
```

### Endpoints de Admin

```bash
# Listar modelos
curl http://localhost:8080/v1/models

# Health check
curl http://localhost:8080/health

# Métricas Prometheus
curl http://localhost:8080/metrics

# Dashboard web
curl http://localhost:8080/dashboard

# Sesiones admin (requiere auth)
curl -H "Authorization: Bearer <token>" http://localhost:8080/admin/sessions
```

---

## Visión de Arquitectura

| Capa | Responsabilidad | Módulos Clave |
|------|----------------|---------------|
| **HTTP** | API, dashboard, métricas | `ElPaso.HTTP.Server`, `ElPaso.HTTP.Dashboard` |
| **Router** | Clasificación de tareas, selección de modelo | `ElPaso.Domain.Router`, `ElPaso.Domain.RouterAnalyzer` |
| **Engine** | Abstracción de adaptadores | `ElPaso.Engine.Adapter`, `ElPaso.Engine.Dispatcher` |
| **Contexto** | Almacenamiento de sesiones, mensajes | `ElPaso.Context.Storage`, `ElPaso.Context.Schemas` |
| **Config** | Config INI con caché ETS | `ElPaso.Config.Loader` |

El router clasifica peticiones por tipo de tarea:

| Tipo de Tarea | Descripción | Modelo Típico |
|---------------|-------------|---------------|
| `code` | Programación, depuración | Qwen, DeepSeek-Coder |
| `reasoning` | Lógica, matemáticas, explicación | R1, o1 |
| `summarization` | Resumen de texto | Gemma, Haiku |
| `creative` | Escritura, brainstorming | GPT-4, Claude |
| `translation` | Traducción de idiomas | NLLB, Aya |
| `question_answer` | Preguntas factuales | Cualquier modelo general |

El `RouterAnalyzer` rastrea tasas de éxito y porcentajes de retry por combinación `(modelo, tarea)`, generando alertas cuando el rendimiento se degrada. `AutoTuner` ajusta periódicamente los scores de afinidad basándose en estos análisis.
