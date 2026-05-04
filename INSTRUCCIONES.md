# 🚀 INSTRUCCIONES DE USO — ElPaso v0.1.0

> **Proxy de inferencia multi-modelo para LLMs locales y remotos**

---

## 📋 Requisitos Previos

| Requisito | Versión mínima | Nota |
|-----------|---------------|------|
| **Elixir** | 1.19.5 | Con OTP 28 |
| **Erlang/OTP** | 28 | `erl -version` |
| **PostgreSQL** | 14+ | Para persistencia |
| **Git** | cualquiera | Para clonar |

---

## 🔧 Instalación

### 1. Clonar y posicionarse

```bash
git clone https://github.com/Lorenzo-SF/ElPaso.git
cd elpaso
```

### 2. Instalar dependencias

```bash
mix deps.get
mix compile
```

Las dependencias locales (`zaguan`, `batamanta`) deben estar en `../zaguan` y `../batamanta` relativas al proyecto. Si no existen, instálalas primero o modifica sus paths en `mix.exs`.

### 3. Configurar la base de datos

Asegúrate de que PostgreSQL esté corriendo. Luego:

```bash
# Crea la base de datos (dev)
mix ecto.create

# Ejecuta las migraciones
mix ecto.migrate
```

Si prefieres usar variables de entorno:

```bash
export DATABASE_URL="postgresql://usuario:password@localhost/elpaso_dev"
mix ecto.create
mix ecto.migrate
```

### 4. (Opcional) Generar el ejecutable

```bash
mix escript.build
# Genera el binario 'elpaso' en el directorio actual
./elpaso --help
```

Para instalarlo globalmente:

```bash
mix deploy
# Lo copia a ~/.elpaso/elpaso
```

---

## ⚡ Inicio Rápido

### Arrancar el servidor

```bash
# Con escript:
./elpaso server start

# O directamente con mix:
mix run --no-halt -e 'ElPaso.CLI.main(["server", "start"])'
```

Por defecto arranca en `http://localhost:8080`.

### Probar que funciona

```bash
# Ver estado
./elpaso server status

# Dashboard web
open http://localhost:8080/dashboard

# Métricas
curl http://localhost:8080/metrics
```

---

## 📡 Configuración de Motores y Modelos

ElPaso no trae modelos preconfigurados. Debes registrar tus motores de inferencia y los modelos que expone cada uno.

### Añadir un motor de inferencia

```bash
# llama.cpp (servidor local)
./elpaso engine add \
  --name llama-server \
  --adapter llama \
  --base-url http://localhost:8081/v1

# Ollama (local)
./elpaso engine add \
  --name ollama-local \
  --adapter ollama \
  --base-url http://localhost:11434

# OpenAI (remoto)
./elpaso engine add \
  --name openai \
  --adapter openai \
  --base-url https://api.openai.com/v1 \
  --api-key sk-tu-api-key

# Anthropic (remoto)
./elpaso engine add \
  --name anthropic \
  --adapter anthropic \
  --base-url https://api.anthropic.com \
  --api-key sk-ant-tu-api-key
```

**Adaptadores soportados:**

| Adaptador | Para | URL típica |
|-----------|------|-----------|
| `llama` | llama.cpp server | `http://localhost:8081/v1` |
| `ollama` | Ollama | `http://localhost:11434` |
| `openai` | OpenAI o compatible (Groq, Together, vLLM) | `https://api.openai.com/v1` |
| `anthropic` | Anthropic Claude | `https://api.anthropic.com` |

### Añadir un modelo

```bash
# Modelo en llama.cpp
./elpaso model add \
  --name gemma-3-4b \
  --engine llama-server \
  --url http://localhost:8081/v1

# Modelo en Ollama
./elpaso model add \
  --name llama3 \
  --engine ollama-local \
  --url http://localhost:11434

# Modelo en OpenAI
./elpaso model add \
  --name gpt-4o \
  --engine openai \
  --url https://api.openai.com/v1 \
  --max-tokens 8192 \
  --temperature 0.7
```

### Verificar conectividad

```bash
# Testear que un motor responde
./elpaso engine test --name llama-server

# Listar todos los motores
./elpaso engine list

# Listar todos los modelos
./elpaso model list
```

### Gestión de modelos

```bash
# Activar/desactivar
./elpaso model update --name gemma-3-4b --active false
./elpaso model start --name gemma-3-4b   # activar
./elpaso model stop --name gemma-3-4b    # desactivar

# Ver detalles
./elpaso model show --name gemma-3-4b

# Eliminar
./elpaso model delete --name gemma-3-4b
```

---

## 🌐 Uso de la API HTTP

### Chat (formato Anthropic)

```bash
curl -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: sk-local" \
  -d '{
    "model": "auto",
    "max_tokens": 1024,
    "messages": [
      {"role": "user", "content": "Explica qué es una mónada en programación funcional."}
    ]
  }'
```

**Respuesta:**
```json
{
  "id": "msg_a1b2c3d4",
  "type": "message",
  "role": "assistant",
  "content": [{"type": "text", "text": "Una mónada es..."}],
  "model": "auto",
  "stop_reason": "end_turn",
  "usage": {"input_tokens": 15, "output_tokens": 200}
}
```

### Streaming (SSE)

```bash
curl -X POST http://localhost:8080/v1/messages_stream \
  -H "Content-Type: application/json" \
  -H "x-api-key: sk-local" \
  -d '{
    "model": "auto",
    "max_tokens": 500,
    "messages": [
      {"role": "user", "content": "Escribe un poema sobre Elixir."}
    ],
    "stream": true
  }'
```

### Obtener token JWT (si auth habilitada)

```bash
curl -X POST http://localhost:8080/auth/token \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "admin",
    "api_key": "sk-local"
  }'
```

### Health check

```bash
curl http://localhost:8080/status
```

---

## ⚙️ Configuración

### Archivo de configuración

Se encuentra en `~/.config/elpaso/elpaso.conf`:

```ini
[http]
port = 8080
host = "localhost"

[models]
default_engine = "llama_server"

[logging]
level = "info"

[cluster]
enabled = false
discovery = "gossip"
```

Gestionarlo desde CLI:

```bash
# Ver configuración
./elpaso config show

# Cambiar un valor
./elpaso config set --section http --key port --value 9090

# Recargar sin reiniciar
./elpaso config reload
```

### Variables de entorno

| Variable | Descripción | Default |
|----------|-------------|---------|
| `ELPASO_PORT` | Puerto HTTP | `8080` |
| `ELPASO_JWT_SECRET` | Secreto para firmar JWT | ⚠️ **requerido en prod** |
| `ELPASO_AUTH_ENABLED` | Activar autenticación | `false` |
| `ELPASO_CLUSTER_ENABLED` | Activar cluster | `false` |
| `DATABASE_URL` | Conexión PostgreSQL | `postgresql://postgres:postgres@localhost/elpaso_dev` |
| `DB_HOST` / `DB_USER` / `DB_PASSWORD` / `DB_NAME` | Alternativa a DATABASE_URL | — |

---

## 🧠 Sistema de Routing

Cuando envías `"model": "auto"` en una petición, ElPaso analiza el mensaje y selecciona el mejor modelo disponible.

### Tareas detectadas

El router clasifica el prompt en una de estas categorías:

| Task Type | Cuándo se usa | Modelo ideal |
|-----------|--------------|-------------|
| `code` | Peticiones de código, algoritmos | Modelo especializado en código |
| `reasoning` | Análisis, comparaciones | Modelo con alta capacidad de razonamiento |
| `summarization` | Resúmenes | Modelo rápido y eficiente |
| `translation` | Traducciones | Modelo multilingüe |
| `question_answer` | Preguntas fácticas | Cualquier modelo |
| `unknown` | No clasificado | Fallback al primer modelo activo |

### Afinidades (Task Affinity)

Cada modelo tiene un mapa de afinidad por tipo de tarea (0.0 = nunca usar, 1.0 = ideal). Puedes consultar las reglas activas:

```bash
./elpaso router rules
```

### Auto-tuning

El sistema puede aprender qué modelos funcionan mejor para cada tarea:

```bash
# Ver estadísticas de routing
./elpaso router stats

# Ejecutar auto-tuneo manual
./elpaso router tune

# Revertir último auto-tuneo
./elpaso router tune --revert-auto
```

El `AutoTuner` se ejecuta automáticamente cada 24 horas (configurable) y ajusta las afinidades basándose en tasas de éxito y latencia.

---

## 📊 Monitoreo

### Dashboard web

```
http://localhost:8080/dashboard
```

### Métricas Prometheus

```
http://localhost:8080/metrics
```

### Logs

```bash
# Ver últimas 100 líneas
./elpaso server log --lines 100

# Logs en archivo (si están configurados)
tail -f log/elpaso.log
```

### Sesiones y contexto

```bash
# Listar sesiones
./elpaso context list

# Ver detalle de sesión
./elpaso context show <session_id>

# Limpiar sesiones
./elpaso context clear --all
```

---

## 🖥️ Cluster (Modo Distribuido)

Varios nodos ElPaso pueden formar un cluster para compartir carga.

### Activar cluster

En `~/.config/elpaso/elpaso.conf`:
```ini
[cluster]
enabled = true
discovery = "gossip"
```

O por variable de entorno:
```bash
export ELPASO_CLUSTER_ENABLED=true
export ELPASO_CLUSTER_DISCOVERY=gossip
```

### Comandos de cluster

```bash
# Ver estado
./elpaso cluster status

# Ver nodos
./elpaso cluster nodes

# Unirse a nodos específicos
./elpaso cluster join --nodes 192.168.1.10,192.168.1.11
```

### Modos de descubrimiento

- **`gossip`**: Descubrimiento automático vía multicast UDP (puerto 45892). Usa `libcluster`.
- **`static`**: Lista fija de nodos configurados en `coordinator_nodes` y `worker_nodes`.

---

## 🔐 Seguridad

### Autenticación JWT

```bash
# Activar (en config o env var)
export ELPASO_AUTH_ENABLED=true
export ELPASO_JWT_SECRET="tu-secreto-seguro-de-64-caracteres"
```

Luego obtén un token:
```bash
curl -X POST http://localhost:8080/auth/token \
  -H "Content-Type: application/json" \
  -d '{"user_id": "mi-usuario", "api_key": "sk-local"}'
```

Usa el token en peticiones:
```bash
curl http://localhost:8080/v1/messages \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","max_tokens":100,"messages":[{"role":"user","content":"Hola"}]}'
```

### Rate Limiting

El rate limiter usa un algoritmo de token bucket. Por defecto permite 60 RPM. Configurable.

---

## 🛠️ Desarrollo y Testing

```bash
# Ejecutar tests
mix test

# Ejecutar tests con coverage
mix test --cover

# Formatear código
mix format

# Análisis estático
mix credo --strict

# Dialyzer
mix dialyzer
```

---

## 🐛 Solución de Problemas

### Error: "module ElPaso.Domain.ModelManager was given as a child but does not implement child_spec/1"

Asegúrate de que el módulo GenServer tiene una función `child_spec/1` o `use GenServer` (que la genera automáticamente).

### Error: conexión a PostgreSQL rechazada

```bash
# Verifica que PostgreSQL corre
pg_isready

# Verifica credenciales (default: postgres/postgres)
psql -U postgres -h localhost -c "SELECT 1"
```

### Error: "migrations can't be executed"

```bash
# Recrear la BD desde cero (entorno dev)
mix ecto.drop
mix ecto.create
mix ecto.migrate
```

### Error: "function :crypto.strong_rand_bytes/1 undefined"

Estás usando una versión de OTP anterior a la 28. Actualiza Elixir/OTP.

### El servidor arranca pero no encuentra modelos

Registra modelos y motores primero:
```bash
./elpaso engine add --name llama-server --adapter llama --base-url http://localhost:8081/v1
./elpaso model add --name mi-modelo --engine llama-server --url http://localhost:8081/v1
```

---

## 📁 Estructura del Proyecto

```
elpaso/
├── config/           # Configuración por entorno (dev, test, prod, runtime)
├── lib/el_paso/
│   ├── cli.ex        # CLI principal (1846 líneas)
│   ├── config.ex     # Cargador de configuración (archivo INI + env vars)
│   ├── application.ex# Árbol de supervisión OTP
│   ├── context/      # Persistencia (PostgreSQL vía Ecto)
│   │   ├── storage.ex
│   │   └── schemas/  # Schemas: session, message, routing_decision, etc.
│   ├── domain/       # Lógica de negocio
│   │   ├── router.ex         # Selección de modelo por task affinity
│   │   ├── router_analyzer.ex# Análisis de tendencias (regresión lineal)
│   │   ├── auto_tuner.ex     # Auto-tuning periódico
│   │   ├── model_manager.ex  # GenServer de gestión de modelos
│   │   └── router/           # ModelState + Cluster router
│   ├── engine/       # Adaptadores de inferencia
│   │   ├── adapter.ex        # Dispatch openai/anthro/ollama/llama
│   │   ├── http_client.ex    # Cliente HTTP vía Finch
│   │   └── dispatcher.ex     # Punto de entrada único (stub)
│   ├── http/         # Servidor HTTP
│   │   ├── server.ex         # Plug.Router con endpoints
│   │   └── anthropic/        # Proxy Anthropic API ↔ formato interno
│   ├── models/       # Schemas Ecto: model, engine, personality, profile, user, etc.
│   ├── security/     # JWT, Auth, RateLimiter
│   ├── telemetry/    # Store de eventos (GenServer)
│   ├── cluster/      # NodeRegistry para cluster distribuido
│   └── downloader/   # Descarga de modelos desde HuggingFace
├── priv/repo/
│   └── migrations/   # 2 migraciones: initial_tables + initial_setup
└── test/             # 24 archivos de test
```

---

## 📞 Referencia Rápida de Comandos

```bash
# Ayuda
./elpaso --help
./elpaso model --help
./elpaso engine --help

# Motores
./elpaso engine add --name <n> --adapter <a> --base-url <url>
./elpaso engine list
./elpaso engine test --name <n>
./elpaso engine delete --name <n>

# Modelos
./elpaso model add --name <n> --engine <e> --url <url>
./elpaso model list
./elpaso model show --name <n>
./elpaso model start --name <n>
./elpaso model stop --name <n>
./elpaso model delete --name <n>

# Servidor
./elpaso server start [--port 9090]
./elpaso server stop
./elpaso server restart
./elpaso server status
./elpaso server log --lines 50

# Router
./elpaso router stats
./elpaso router tune
./elpaso router rules

# Configuración
./elpaso config show
./elpaso config set --section <s> --key <k> --value <v>

# Base de datos
./elpaso db create
./elpaso db migrate
./elpaso db status

# Sesiones
./elpaso context list
./elpaso context show <id>
./elpaso context clear --all

# Cluster
./elpaso cluster status
./elpaso cluster nodes
```

---

*ElPaso — Multi-Model LLM Proxy. Documentación generada 2026-05-04.*
