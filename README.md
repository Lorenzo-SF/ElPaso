# 🚀 El Paso

**Multi-model LLM proxy written in Elixir**

El Paso decide cuál usar en cada momento.

## ¿Qué es El Paso?

El Paso es un **proxy de inferencia multi-modelo** que te da un único endpoint para acceder a múltiples LLMs — locales (llama.cpp, Ollama, vLLM) o remotos (OpenAI, Anthropic).

```
┌─────────────────────────────────────────────────────┐
│                    Tu App                           │
│                      ↓                             │
│               POST /v1/chat/completions            │
│                      ↓                             │
│  ┌─────────────────────────────────────────┐      │
│  │  🤖 El Paso Router                     │      │
│  │  "Necesito código" → coder (Qwen)      │      │
│  │  "Explica esto"   → reasoning (R1)    │      │
│  │  "Resumen"        → fast (Gemma)       │      │
│  └─────────────────────────────────────────┘      │
│                      ↓                             │
│        ┌──────────┬──────────┬──────────┐        │
│        │  llama   │  Ollama  │  OpenAI  │        │
│        │  server  │  local  │   API    │        │
│        └──────────┴──────────┴──────────┘        │
└─────────────────────────────────────────────────────┘
```

## Características Principales

- 🧠 **Enrutamiento Inteligente** — Elige el mejor modelo según el tipo de tarea
- 🔄 **Contexto Portable** — La conversación sigue al usuario entre modelos
- ⚡ **Gestión de Motores** — Arrancar/parar modelos automáticamente
- 💾 **Cache LRU+TTL** — Evita repetir inferencias costosas
- 📊 **Métricas** — Prometheus + Telemetry integrado
- 🔐 **Auth** — JWT y rate limiting integrados

## Inicio Rápido

```bash
# 1. Instalar dependencias
mix deps.get

# 2. Compilar
mix compile

# 3. Arrancar el servidor
mix run --no-halt

# 4. Probar
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hola!"}],
    "model": "auto"
  }'
```

## API

| Endpoint | Método | Descripción |
|---------|--------|-------------|
| `/v1/chat/completions` | POST | Chat completo (compat OpenAI) |
| `/v1/messages` | POST | Anthropic API compat |
| `/v1/messages_stream` | POST | Streaming |
| `/models/status` | GET | Estado de modelos |
| `/status` | GET | Estado del sistema + alertas |
| `/dashboard` | GET | Dashboard web |
| `/metrics` | GET | Métricas Prometheus |

### Overrides de El Paso

```json
{
  "messages": [...],
  "elpaso": {
    "session_id": "mi-sesion",
    "force_model": "gemma",
    "context_mode": "transparent",
    "window_size": 10
  }
}
```

## Configuración

Edita `config/runtime.exs` o usa variables de entorno:

```elixir
config :elpaso,
  api_key: System.get_env("ELPASO_API_KEY"),
  port: System.get_env("ELPASO_PORT", "8080") |> String.to_integer()
```

### Modelos Disponibles

| ID | Modelo | Especialidad | VRAM |
|----|--------|-------------|------|
| `fast` | Gemma 3 4B | Rápido, tareas simples | 4GB |
| `heavy` | Llama 3 8B | Tareas complejas | 8GB |
| `coder` | Qwen Coder | Código | 6GB |
| `r1` | DeepSeek R1 | Razonamiento | 4GB |

## Estructura del Proyecto

```
lib/el_paso/
├── context/           # Gestión de conversaciones
│   ├── builder.ex    # Ensambla el prompt
│   ├── manager.ex    # Estado en memoria
│   ├── storage.ex   # Persistencia PostgreSQL
│   └── schemas/     # Ecto schemas
├── domain/           # Lógica de negocio
│   ├── router.ex     # Enrutamiento heurístico
│   ├── model_manager.ex  # Ciclo de vida de modelos
│   └── auto_tuner.go # Ajuste automático
├── engine/           # Motores de inferencia
│   ├── dispatcher.ex # Punto de entrada
│   └── ollama.ex    # Adapter Ollama
├── http/             # Servidor HTTP
└── security/         # Auth & rate limiting
```

## Desarrollo

```bash
# Tests
mix test

# Credo (linting)
mix credo

# Deps/update
mix deps.update --all
```

## Licencia

MIT