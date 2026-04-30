# ElPaso - Multi-Model LLM Proxy

**ElPaso** es un proxy de inferencia multi-modelo escrito en Elixir que proporciona un único endpoint para acceder a múltiples LLMs — locales (llama.cpp, Ollama, vLLM) o remotos (OpenAI, Anthropic).

## Tabla de Contenidos

1. [¿Qué es ElPaso?](#qué-es-elpaso)
2. [Características](#características)
3. [Requisitos](#requisitos)
4. [Instalación](#instalación)
5. [Inicio Rápido](#inicio-rápido)
6. [Configuración](#configuración)
7. [Comandos CLI](#comandos-cli)
8. [API HTTP](#api-http)
9. [Arquitectura](#arquitectura)
10. [Desarrollo](#desarrollo)

---

## ¿Qué es ElPaso?

ElPaso es un **proxy de inferencia multi-modelo** queacting como un gateway inteligente entre tu aplicación y múltiples proveedores de modelos de lenguaje.

```
┌─────────────────────────────────────────────────────┐
│                   Tu Aplicación                     │
│                      ↓                             │
│           POST /v1/chat/completions                │
│                      ↓                             │
│  ┌─────────────────────────────────────────────┐   │
│  │         🤖 El Paso Router                    │   │
│  │         "Necesito código" → coder (Qwen)      │   │
│  │         "Explícamelo" → reasoning (R1)      │   │
│  │         "Resume esto" → fast (Gemma)         │   │
│  └─────────────────────────────────────────────┘   │
│                      ↓                             │
│        ┌──────────┬──────────┬───────────┐        │
│        │  llama  │  Ollama  │  OpenAI   │        │
│        │ server  │  local   │    API    │        │
│        └──────────┴──────────┴───────────┘        │
└─────────────────────────────────────────────────────┘
```

### ¿Por qué usar ElPaso?

- **Un única API** para todos tus modelos (OpenAI compatible)
- **Smart Routing** — Elige el mejor modelo según el tipo de tarea
- **Contexto Portátil** — La conversación sigue al usuario entre modelos
- **Gestión de Motores** — Auto inicio/parada de modelos
- **Cache LRU+TTL** — Evita repetir inferencias costosas
- **Métricas** — Prometheus + Telemetry integrados
- **Auth** — JWT y rate limiting integrados
- **Cluster** — Modo cluster con descubrimiento automático

---

## Requisitos

- **Elixir** 1.19+ (recomendado)
- **OTP** 28+ (recomendado)
- **PostgreSQL** 14+ (para persistencia de sesiones)
- **Linux/macOS** (Windows con WSL2 puede funcionar)

---

## Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/lorenzo-sf/elpaso.git
cd elpaso
```

### 2. Instalar dependencias

```bash
mix deps.get
```

### 3. Compilar

```bash
mix compile
```

### 4. Crear la base de datos

```bash
# Configurar conexión a PostgreSQL en config/dev.exs o via env vars
export DATABASE_URL="postgresql://user:password@localhost/elpaso"

mix ecto.create
mix ecto.migrate
```

### 5. Configurar variables de entorno

```bash
# Archivo .env (no compartir)
export ELPASO_INFERENCE_URL="http://localhost:8081/v1"
export ELPASO_INFERENCE_API_KEY="sk-local-test"
export ELPASO_AUTH_ENABLED="false"
export ELPASO_PORT="8080"
export DATABASE_URL="postgresql://user:password@localhost/elpaso"
```

### 6. Iniciar el servidor

```bash
elpaso server start
```

El servidor arrancará en `http://localhost:8080` (o el puerto configurado).

---

## Configuración

### Variables de Entorno

ElPaso requiere las siguientes variables de entorno:

| Variable | Descripción | Requerido | Default |
|----------|-------------|----------|---------|
| `ELPASO_INFERENCE_URL` | URL del servidor de inferencia | Sí | - |
| `ELPASO_INFERENCE_API_KEY` | API key para autenticación | Sí | - |
| `DATABASE_URL` | URL de PostgreSQL | Sí | - |
| `ELPASO_PORT` | Puerto HTTP | No | `8080` |
| `ELPASO_AUTH_ENABLED` | Habilitar autenticación | No | `false` |
| `ELPASO_CLUSTER_ENABLED` | Habilitar modo cluster | No | `false` |
| `ELPASO_MODEL_ROUTING` | Habilitar routing automático | No | `false` |

### Configuración de Motores Soportados

| Adaptador | Descripción | Ejemplo URL |
|----------|-------------|------------|
| `openai` | OpenAI API compatible | `https://api.openai.com/v1` |
| `ollama` | Ollama local | `http://localhost:11434/v1` |
| `anthropic` | Anthropic API | `https://api.anthropic.com` |
| `vllm` | vLLM API | `http://localhost:8001/v1` |
| `llama` | Llama.cpp server | `http://localhost:8080/v1` |
| `airllm` | AirLLM | `http://localhost:8000/v1` |

### Modelos Disponibles

| ID | Modelo | Especialidad | VRAM |
|----|--------|-------------|------|
| `fast` | Gemma 3 4B | Tareas rápidas, simples | 4GB |
| `heavy` | Llama 3 8B | Tareas complejas | 8GB |
| `coder` | Qwen Coder | Generación de código | 6GB |
| `r1` | DeepSeek R1 | Razonamiento | 4GB |

---

## Comandos CLI

### help del sistema

```bash
# Ver ayuda general
mix elpaso

# Ver toda la ayuda
mix elpaso --help
```

### model — Gestión de Modelos

```bash
# Ver ayuda del comando model
mix elpaso model --help

# Añadir modelo con motor llama.cpp
mix elpaso model add \
  --name llama-3-8b \
  --engine llama-server \
  --url http://localhost:8080/v1

# Añadir modelo con motor vLLM (GPU optimizado)
mix elpaso model add \
  --name mixtral-8x7b \
  --engine vllm-gpu \
  --url http://localhost:8000/v1 \
  --description "Modelo mixto optimizado" \
  --max-tokens 32768

# Añadir modelo con motor AirLLM (CPU optimizado)
mix elpaso model add \
  --name airllm-qwen \
  --engine airllm \
  --url http://localhost:8000/v1

# Añadir modelo con motor Ollama (servidor externo)
mix elpaso model add \
  --name llama3-remote \
  --engine ollama-remote \
  --url http://192.168.1.100:11434/v1
```

**Opciones disponibles:**
- `--name` — Nombre único del modelo (REQUERIDO)
- `--engine` — ID del motor (REQUERIDO)
- `--url` — URL del endpoint (REQUERIDO)
- `--api-key` — API key (opcional)
- `--description` — Descripción (opcional)
- `--active` — Si está activo (default: true)
- `--max-tokens` — Máximo de tokens (opcional)
- `--temperature` — Temperatura default (default: 0.7)

### engine — Gestión de Motores

```bash
# Ver ayuda del comando engine
mix elpaso engine --help

# Añadir motor llama.cpp (servidor HTTP local)
mix elpaso engine add \
  --name llama-server \
  --adapter llama \
  --base-url http://localhost:8080

# Añadir motor vLLM (API GPU optimizada)
mix elpaso engine add \
  --name vllm-gpu \
  --adapter vllm \
  --base-url http://localhost:8000/v1

# Añadir motor AirLLM (optimizado para CPU)
mix elpaso engine add \
  --name airllm \
  --adapter airllm \
  --base-url http://localhost:8000/v1

# Añadir motor Ollama (servidor externo)
mix elpaso engine add \
  --name ollama-remote \
  --adapter ollama \
  --base-url http://192.168.1.100:11434/v1
```

**Opciones disponibles:**
- `--name` — Nombre único del motor (REQUERIDO)
- `--adapter` — Tipo de adaptador (REQUERIDO)
- `--base-url` — URL base (REQUERIDO)
- `--api-key` — API key (opcional)
- `--description` — Descripción (opcional)
- `--active` — Si está activo (default: true)
- `--timeout` — Timeout en ms (default: 60000)

### config — Gestión de Configuración

```bash
# Ver ayuda del comando config
mix elpaso config --help

# Mostrar configuración actual
mix elpaso config show

# Recargar configuración desde DB
mix elpaso config reload
```

### router — Estadísticas y Auto-tuneo

```bash
# Ver ayuda del comando router
mix elpaso router --help

# Ver estadísticas de routing
mix elpaso router stats

# Ver estadísticas de un modelo específico
mix elpaso router stats --model gpt-4

# Ejecutar auto-tuneo
mix elpaso router tune

# Ver reglas activas
mix elpaso router rules
```

### bench — Benchmarks

```bash
# Ver ayuda del comando bench
mix elpaso bench --help

# Ejecutar benchmark básico
mix elpaso bench run

# Benchmark con modelos específicos
mix elpaso bench run --models gpt-4,claude-3

# Benchmark de carga
mix elpaso bench run --concurrency 10 --duration 60
```

**Opciones disponibles:**
- `--models` — Modelos a testar (comma-separated)
- `--prompt` — Prompt de prueba
- `--concurrency` — Peticiones concurrentes
- `--duration` — Duración en segundos
- `--max-tokens` — Máximo de tokens
- `--temperature` — Temperatura

### context — Gestión de Contextos

```bash
# Ver ayuda del comando context
mix elpaso context --help

# Listar sesiones activas
mix elpaso context list

# Ver contexto de sesión
mix elpaso context show session_id_123

# Limpiar todas las sesiones
mix elpaso context clear --all
```

**Opciones disponibles:**
- `--session` — ID de sesión
- `--all` — Todas las sesiones
- `--user` — Filtrar por usuario
- `--limit` — Límite de resultados

### cluster — Estado del Cluster

```bash
# Ver ayuda del comando cluster
mix elpaso cluster --help

# Ver estado del cluster
mix elpaso cluster status

# Ver nodos
mix elpaso cluster nodes

# Unirse al cluster con gossip
mix elpaso cluster join --discovery gossip
```

**Opciones disponibles:**
- `--discovery` — Modo: gossip, static
- `--nodes` — Nodos iniciales (comma-separated)
- `--port` — Puerto de cluster

---

## API HTTP

### Endpoints Disponibles

| Endpoint | Método | Descripción |
|----------|--------|-------------|
| `/v1/chat/completions` | POST | Chat completion (OpenAI compatible) |
| `/v1/messages` | POST | Anthropic API compatible |
| `/v1/messages/stream` | POST | Streaming |
| `/v1/models` | GET | Listar modelos disponibles |
| `/models/status` | GET | Estado de modelos |
| `/health` | GET | Health check |
| `/status` | GET | Estado del sistema + alertas |
| `/dashboard` | GET | Web dashboard |
| `/metrics` | GET | Métricas Prometheus |
| `/auth/token` | POST | Obtener token JWT |
| `/admin/*` | GET/POST | Endpoints admin |

### Chat Completion

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer tu-token" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello!"}
    ],
    "model": "auto"
  }'
```

**Parámetros:**
- `messages` — Array de mensajes (requerido)
- `model` — ID del modelo o "auto" (default: "auto")
- `temperature` — Temperatura (default: 0.7)
- `max_tokens` — Máximo de tokens (opcional)
- `stream` — Streaming response (default: false)

### Parámetros de ElPaso

```json
{
  "messages": [...],
  "model": "auto",
  "elpaso": {
    "session_id": "mi-sesion",
    "force_model": "gemma",
    "context_mode": "transparent",
    "window_size": 10
  }
}
```

### Health Check

```bash
curl http://localhost:8080/health
```

Respuesta:
```json
{
  "status": "healthy",
  "version": "0.1.0",
  "models": ["gpt-4", "claude-3", "gemma"],
  "uptime_seconds": 3600
}
```

---

## Arquitectura

```
lib/el_paso/
├── context/              # Gestión de conversaciones
│   ├── builder.ex       # Construye el prompt
│   ├── manager.ex       # Estado en memoria
│   ├── storage.ex       # Persistencia PostgreSQL
│   └── summaries/       # Resúmenes de sesión
├── domain/              # Lógica de negocio
│   ├── router.ex        # Routing heurístico
│   ├── model_manager.ex # Ciclo de vida de modelos
│   └── auto_tuner.clusters  # Auto-tuning
├── engine/              # Motores de inferencia
│   ├── dispatcher.ex    # Punto único de entrada
│   ├── ollama.ex       # Adaptador Ollama
│   ├── openai.ex       # Adaptador OpenAI
│   ├── anthropic.ex    # Adaptador Anthropic
│   └── vllm.ex        # Adaptador vLLM
├── http/                # Servidor HTTP
│   ├── server.ex       # Plug.Cowboy
│   ├── routes/         # Definiciones de rutas
│   └── middleware/    # Middleware Plugs
├── security/           # Auth y rate limiting
│   ├── auth.ex         # Autenticación JWT
│   ├── rate_limiter.ex # Rate limiting
│   └── access.ex       # Control de acceso
├── telemetry/          # Métricas
│   ├── store.ex        # Almacén de métricas
│   └── reporter.ex    # Reporter Prometheus
└── cluster/            # Soporte cluster
    ├── supervisor.ex   # Supervisor de cluster
    └── node_registry  # Registro de nodos
```

### Flujo de una Petición

1. **HTTP Request** → Llega a `/v1/chat/completions`
2. **Auth Middleware** → Valida JWT (si está habilitado)
3. **Rate Limit** → Checkea límites
4. **Router** → Elige el mejor modelo según el prompt
5. **Context Builder** → Prepara el contexto
6. **Engine Dispatcher** → Llama al motor correcto
7. **Engine Adapter** → Convierte y llama al inference server
8. **Response** → Devuelve al cliente

---

## Desarrollo

### Ejecutar tests

```bash
export ELPASO_INFERENCE_URL="http://localhost:8081/v1"
export ELPASO_INFERENCE_API_KEY="sk-local-test"
export ELPASO_AUTH_ENABLED="false"
export DATABASE_URL="postgresql://user:password@localhost/elpaso_test"

mix test
```

### Ejecutar con IEx

```bash
iex -S mix
```

### Quality checks

```bash
mix format        # Formatear código
mix compile     # Compilar
mix credo       # Análisis de código
mix credo --strict  # Análisis estricto
```

### Generar documentación

```bash
mix docs
```

### Builds

```bash
# Generar escript
mix escript.build

# Generar release
MIX_ENV=prod mix release
```

---

## Troubleshooting

### Error: "The module ElPaso.Domain.ModelManager was given as a child to a supervisor but it does not implement child_spec/1"

**Solución:** El módulo no implementa correctamente `child_spec/1`. Asegúrate de tener:

```elixir
def child_spec(opts) do
  %{
    id: __MODULE__,
    start: {__MODULE__, :start_link, [opts]},
    type: :worker,
    restart: :permanent,
    shutdown: 500
  }
end
```

### Error: "migrations can't be executed, migration version X is duplicated"

**Solución:** Limpiar migrations duplicadas:

```bash
# Eliminar archivos de migración duplicados
rm priv/repo/migrations/20240426*.exs

# Recrear base de datos
mix ecto.drop
mix ecto.create
mix ecto.migrate
```

### Error: "undefined function cast/3"

**Solución:** El módulo no tiene las funciones de Ecto importadas. Añadir:

```elixir
import Ecto.Changeset
import Ecto.Query
```

### Ver logs en producción

```bash
# Con systemd
journalctl -u elpaso -f

# Directo
tail -f log/elpaso.log
```

---

## Licencia

MIT

---

## Contributing

1. Fork el repositorio
2. Crear rama (`git checkout -b feature/foo`)
3. Commit cambios (`git commit -am 'Add feature'`)
4. Push rama (`git push origin feature/foo`)
5. Crear Pull Request

---

## Contacto

- **GitHub:** https://github.com/tu-usuario/elpaso
- **Issues:** https://github.com/tu-usuario/elpaso/issues
