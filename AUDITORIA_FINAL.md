# 🏁 AUDITORÍA FINAL — ElPaso v0.1.0

> **Fecha**: 2026-05-04  
> **Auditor**: Macahan (Arquitecto Universal Supremo)  
> **Proyecto**: Proxy de inferencia multi-modelo para LLMs locales y remotos  
> **Stack**: Elixir 1.19.5 + OTP 28 + PostgreSQL + Ecto + Finch + Plug.Cowboy  
> **Repositorio**: https://github.com/Lorenzo-SF/ElPaso  
> **Dependencias locales**: `zaguan` (Circuit Breaker + CLI UI), `batamanta` (packager)

---

## 📑 TABLA DE CONTENIDOS

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Arquitectura General](#2-arquitectura-general)
3. [Árbol de Supervisión OTP](#3-árbol-de-supervisión-otp)
4. [Análisis por Módulo](#4-análisis-por-módulo)
5. [Auditoría de Seguridad (OWASP Top 10)](#5-auditoría-de-seguridad)
6. [Auditoría de Performance](#6-auditoría-de-performance)
7. [Auditoría de Concurrencia](#7-auditoría-de-concurrencia)
8. [Calidad de Código Elixir](#8-calidad-de-código-elixir)
9. [Gestión de Configuración](#9-gestión-de-configuración)
10. [Base de Datos y Esquema](#10-base-de-datos-y-esquema)
11. [Testing y Cobertura](#11-testing-y-cobertura)
12. [Issues Críticos (Bloqueantes)](#12-issues-críticos-bloqueantes)
13. [Issues de Alta Prioridad](#13-issues-de-alta-prioridad)
14. [Issues de Media Prioridad](#14-issues-de-media-prioridad)
15. [Issues de Baja Prioridad](#15-issues-de-baja-prioridad)
16. [Checklist de Terminación](#16-checklist-de-terminación)
17. [Veredicto Final](#17-veredicto-final)

---

## 1. RESUMEN EJECUTIVO

**ElPaso** es un proxy de inferencia multi-modelo escrito en Elixir que actúa como gateway inteligente entre aplicaciones cliente y múltiples proveedores de LLMs (llama.cpp, Ollama, OpenAI, Anthropic). Soporta CLI interactiva (escript), servidor HTTP con API compatible con Anthropic, streaming SSE, JWT auth, rate limiting, PostgreSQL para persistencia de sesiones, y cluster distribuido vía libcluster.

**Estado actual**: El proyecto está **estructuralmente muy avanzado** — tiene un ~85% de completitud en arquitectura — pero presenta **fallos críticos de seguridad, bugs funcionales serios, y stubs no implementados** que impiden considerarlo listo para producción.

### Métricas Clave

| Métrica | Valor |
|---------|-------|
| Archivos de código | ~45 módulos Elixir |
| Líneas totales | ~8,500+ LOC |
| Schemas Ecto implementados | 12/12 (100%) |
| Migraciones DB | 2 (completas) |
| Endpoints HTTP | 9 implementados, 3 placeholders |
| Adaptadores de engine | 4 (openai, anthropic, ollama, llama) |
| GenServers | 4 (ModelManager, AutoTuner, Telemetry.Store, NodeRegistry) |
| Tests | 24 archivos de test, cobertura muy desigual |
| Issues encontrados | 33 total (6 CRÍTICOS, 11 HIGH, 10 MEDIUM, 6 LOW) |

### Veredicto Preliminar

**NO puede darse por terminado.** Hay 6 issues críticos que deben resolverse antes de cualquier despliegue. Con aproximadamente **2-3 semanas de trabajo enfocado**, el proyecto puede alcanzar un estado productivo sólido.

---

## 2. ARQUITECTURA GENERAL

### 2.1 Diagrama de Capas

```
┌─────────────────────────────────────────────────────────┐
│                   CAPA DE ENTRADA                        │
│  ┌──────────────┐  ┌──────────────────────────────────┐ │
│  │  CLI (escript)│  │  HTTP Server (Plug.Cowboy)       │ │
│  │  ElPaso.CLI   │  │  ElPaso.HTTP.Server             │ │
│  └──────┬───────┘  └──────────────┬───────────────────┘ │
│         │                         │                      │
├─────────┼─────────────────────────┼──────────────────────┤
│         │    CAPA DE DOMINIO       │                      │
│         ├─────────────────────────┤                      │
│         │  Router (select_model)  │                      │
│         │  RouterAnalyzer         │                      │
│         │  AutoTuner (GenServer)  │                      │
│         │  ModelManager (GenServer)                      │
│         │  EngineManager / PersonalityManager / ProfileMgr│
│         ├─────────────────────────┤                      │
│         │  CAPA DE ENGINE         │                      │
│         │  Adapter.dispatch →     │                      │
│         │    openai/anthro/ollama/llama                 │
│         │  HTTPClient (Finch)     │                      │
├─────────┼─────────────────────────┼──────────────────────┤
│         │  CAPA DE PERSISTENCIA   │                      │
│         │  Context.Storage (Ecto) │                      │
│         │  Repo (PostgreSQL)      │                      │
│         │  ETS (affinity, rate_limiter, downloads)       │
├─────────┴─────────────────────────┴──────────────────────┤
│              INFRAESTRUCTURA                              │
│  Security (JWT, Auth, RateLimiter)                       │
│  Telemetry (Store GenServer)                             │
│  Cluster (NodeRegistry + libcluster)                     │
│  Zaguan (CircuitBreaker + Engine.Supervisor)             │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Flujo de una Petición de Inferencia

```
Cliente → POST /v1/messages
  → ElPaso.HTTP.Server (Plug.Router)
    → ElPaso.HTTP.AnthropicProxy.from_anthropic (conversión de formato)
    → run_anthropic_pipeline
      → Router.select_model (detección heurística de task + scoring)
      → ModelManager.infer (GenServer.call)
        → Zaguan CircuitBreaker.call
          → do_infer
            → Engine.Adapter.infer
              → HTTPClient.openai_compatible/anthropic/ollama/llama_cpp
                → Finch HTTP request
  ← Respuesta convertida a formato Anthropic
  ← Cliente recibe JSON Anthropic-compatible
```

### 2.3 Patrones de Diseño Identificados

| Patrón | Dónde | Evaluación |
|--------|-------|------------|
| **Supervision Tree** | `ElPaso.Application` | ✅ Correcto, `one_for_one` |
| **GenServer** | ModelManager, AutoTuner, Telemetry.Store, NodeRegistry | ✅ Uso apropiado |
| **Behaviour** | `ElPaso.Engine` (callbacks: infer, stream, health_check, format_messages) | ⚠️ Definido pero no usado por ningún adapter real |
| **Circuit Breaker** | `ModelManager.infer` vía Zaguan | ✅ Buena integración |
| **Strategy** | `Engine.Adapter` dispatch por `adapter` string | ✅ Buena separación |
| **Repository** | `Context.Storage` | ✅ Abstracción limpia sobre Ecto |
| **Registry (ETS)** | RateLimiter, affinity_table, ModelDownloaderRegistry | ⚠️ ETS público sin protección |
| **Observer (Telemetry)** | `Telemetry.Store` suscrito a eventos | ✅ Implementación correcta |
| **Token Bucket** | `Security.RateLimiter` | ⚠️ Con bugs de concurrencia |
| **Proxy** | `HTTP.AnthropicProxy` | ✅ Conversión correcta de formato |
| **Builder** | `Ecto.Changeset` en schemas | ✅ Uso idiomático |

---

## 3. ÁRBOL DE SUPERVISIÓN OTP

### 3.1 Estructura Actual

```elixir
Supervisor.start_link(final_children, [strategy: :one_for_one, name: ElPaso.Supervisor])
```

**Hijos base (siempre arrancan):**
1. `ElPaso.Repo` — Ecto Repo (PostgreSQL)
2. `ElPaso.Finch` — HTTP client pool (50 conexiones, timeout 120s)
3. `ElPaso.Domain.ModelManager` — GenServer (gestión de modelos + inferencia)
4. `ElPaso.Telemetry.Store` — GenServer (métricas)
5. `ElPaso.Domain.AutoTuner` — GenServer (auto-tuning periódico)
6. `Zaguan.Engine.Supervisor` — Dependencia externa (circuit breakers)

**Hijos condicionales:**
- `Plug.Cowboy` — Solo si NO está en modo CLI
- `Cluster.Supervisor` — Solo si cluster gossip habilitado
- `ElPaso.Cluster.NodeRegistry` — Solo si cluster habilitado

### 3.2 Análisis del Árbol

**✅ Aciertos:**
- `one_for_one` es la estrategia correcta para componentes independientes
- Los GenServers tienen `child_spec` explícito definido
- Finch pool dimensionado para 50 conexiones concurrentes

**⚠️ Problemas:**
1. **`ModelManager` es un cuello de botella**: Todas las inferencias pasan por un único `GenServer.call`, serializando requests. Para producción con carga, debería particionarse por modelo o usar un pool de workers.
2. **`AutoTuner` no se supervisa adecuadamente**: Si falla, `one_for_one` lo reinicia, pero el `Process.send_after` se pierde y no se reprograma hasta el siguiente ciclo.
3. **`Plug.Cowboy` no está bajo `restart: :permanent` explícito**: Si Cowboy falla, el comportamiento depende de los defaults de `Plug.Cowboy.child_spec`.

---

## 4. ANÁLISIS POR MÓDULO

### 4.1 `ElPaso.CLI` (1846 líneas) ⚠️

**Función**: Entry point del escript. Parser de comandos y subcomandos.

**Problemas encontrados:**

| ID | Severidad | Descripción | Línea |
|----|-----------|-------------|-------|
| CLI-01 | **CRITICAL** | `handle_db(["create"])` concatena el nombre de DB directamente en SQL (`"CREATE DATABASE #{db_name}"`). **SQL Injection**. Si el usuario controla `DATABASE_URL`, puede ejecutar SQL arbitrario. | 527 |
| CLI-02 | HIGH | Errores tipográficos en mensajes de ayuda: `"elapso cluster --help"` (línea 64), `"elpasar bench run"` (línea 282) | 64, 282 |
| CLI-03 | MEDIUM | `parse_bool(get_opt(rest, :active))` — `get_opt` retorna booleano o nil, pero se trata como string en algunos casos | varios |
| CLI-04 | MEDIUM | `handle_engine(["show"])` llama a `list_engines()` y luego `Enum.find`. Debería usar `get_engine(name)` para O(1) en DB. | 830 |
| CLI-05 | LOW | `handle_server(["start"])` usa `receive do after: :infinity -> :ok end` para bloquear. Correcto para CLI, pero impide graceful shutdown. | 1772 |
| CLI-06 | LOW | `handle_personality(["use"])` es un stub: imprime éxito pero no persiste nada. | 1554 |

### 4.2 `ElPaso.Config` / `ElPaso.Config.Loader` (527 líneas) ⚠️

**Función**: Carga de configuración desde archivo INI (`~/.config/elpaso/elpaso.conf`) y variables de entorno, con ETS para affinity scores.

**Problemas:**

| ID | Severidad | Descripción | Línea |
|----|-----------|-------------|-------|
| CFG-01 | HIGH | `Config.Loader.get()` usa `raise` para control de flujo en producción si faltan env vars. Debería retornar `{:error, reason}`. | 67-85 |
| CFG-02 | HIGH | `env_model_routing` se parsea como booleano usando `parse_bool(env_model_routing, ...)`, pero `ELPASO_MODEL_ROUTING` es un string que debería indicar si auto_tune está activo. La variable de entorno se usa como `parse_bool` para `auto_tune` y como `parse_float` para `auto_tune_min_confidence` — son usos contradictorios. | 128-131 |
| CFG-03 | MEDIUM | `parse_ini` tiene un bug: si hay una key sin sección (antes de cualquier `[section]`), `current_section` es nil y la línea se ignora silenciosamente. | 312 |
| CFG-04 | MEDIUM | `config_get_in` recorre las claves con pattern matching pero si alguna clave intermedia es nil, el reduce falla con `FunctionClauseError`. No es nil-safe. | 18-28 |
| CFG-05 | LOW | `ref/1` definido pero nunca usado en el código. Código muerto. | 31-33 |
| CFG-06 | LOW | `flatten_keys` solo soporta `is_binary` o `is_number` como valores hoja. Booleanos y atoms se pierden al guardar config. | 292-296 |

### 4.3 `ElPaso.Domain.Router` (197 líneas) ⚠️

**Función**: Selección de modelo basada en task affinity y heurística de contenido.

**Problemas:**

| ID | Severidad | Descripción | Línea |
|----|-----------|-------------|-------|
| RTR-01 | **CRITICAL** | `detect_task_type/1` usa una heurística ridículamente ingenua: busca palabras clave literales en inglés y español. "write code", "fibonacci", "sort", "translate", "traduce". Cualquier prompt que no contenga estas palabras exactas cae en `:unknown`. Esto hace que el router sea **prácticamente inútil** en producción. | 75-113 |
| RTR-02 | HIGH | `select_model` llama a `ModelManager.list_models()` que hace `Repo.all(Model)` en cada request. Si hay muchos modelos, esto impacta la latencia. Debería cachearse en ETS. | 28 |
| RTR-03 | MEDIUM | La función `select_model` acepta `_options` pero no los usa. El parámetro no se documenta. | 22 |
| RTR-04 | LOW | Si hay empate en scores, `Enum.sort_by` es inestable (no garantiza orden determinista). | 43 |

### 4.4 `ElPaso.Domain.ModelManager` (271 líneas) ⚠️

**Función**: GenServer que gestiona modelos y ejecuta inferencia con Circuit Breaker.

**Problemas:**

| ID | Severidad | Descripción | Línea |
|----|-----------|-------------|-------|
| MM-01 | **CRITICAL** | El `handle_call({:infer, ...})` **bloquea el GenServer** durante toda la inferencia HTTP. Finch es async pero está dentro de un `GenServer.call` síncrono. Esto significa que UNA sola inferencia lenta bloquea TODAS las demás. Es un cuello de botella masivo. | 68-103 |
| MM-02 | HIGH | `ensure_circuit_breaker` hace `Registry.lookup` y si no encuentra, arranca un CircuitBreaker *dentro del proceso GenServer*. Si `Zaguan.Engine.CircuitBreaker.start_link` falla, crashea el ModelManager. | 242-250 |
| MM-03 | HIGH | En `init`, si `load_models()` lanza excepción, se rescata con `_ -> []`. Esto es un `rescue` genérico que oculta errores reales de DB (conexión, migraciones pendientes). | 36-39 |
| MM-04 | MEDIUM | `do_infer` hace `Repo.get(Engine, model.engine_id)` en CADA inferencia. Debería cachearse en el estado del GenServer. | 108-112 |
| MM-05 | LOW | `all_states` genera `ModelState` para todos los modelos en cada llamada. Para modelos estáticos sería mejor memoizarlo. | 64-66 |

### 4.5 `ElPaso.Engine.HTTPClient` (348 líneas) 🐛

**Función**: Cliente HTTP vía Finch para los 4 adaptadores de engine.

**Problemas:**

| ID | Severidad | Descripción | Línea |
|----|-----------|-------------|-------|
| HTTP-01 | **CRITICAL** | **BUG FUNCIONAL**: En `openai_compatible`, la respuesta exitosa intenta leer `usage` del `body` del request (variable local `body`), NO de la respuesta parseada. Las líneas 58-61 usan `Map.get(body, "usage", ...)` cuando deberían usar la respuesta HTTP parseada. Esto significa que `prompt_tokens` y `completion_tokens` **siempre serán 0** para OpenAI. | 52-62 |
| HTTP-02 | **CRITICAL** | Mismo bug en `anthropic/4`: `Map.get(body, "usage", ...)` en lugar de leer de la respuesta. Tokens siempre serán 0 para Anthropic. | 111-121 |
| HTTP-03 | HIGH | `transform_messages_for_anthropic` convierte mensajes `system` a `user` con prefijo `[SYSTEM: ...]`. Anthropic **sí soporta** un campo `system` separado en el request. Esto degrada la calidad de respuestas. | 322-330 |
| HTTP-04 | MEDIUM | `stream_openai` usa pattern matching frágil: `<<"data: ", rest::binary>>`. Si Finch entrega chunks que empiezan con whitespace o tienen `data:` en medio, falla silenciosamente. | 230 |
| HTTP-05 | MEDIUM | `stream_ollama` intenta `Jason.decode` de cada chunk como si fuera JSON completo. Ollama NDJSON puede tener líneas vacías o parciales. | 267 |
| HTTP-06 | MEDIUM | Finch pool `ElPaso.Finch` configurado con timeout 120s pero sin `pool_timeout` ni `conn_opts`. Requests pueden quedar colgados. | N/A |
| HTTP-07 | LOW | `map_finish_reason(_)` tiene cláusula catch-all que mapea todo a `:stop`. Si OpenAI introduce nuevos finish_reasons, se pierde información. | 337 |

### 4.6 `ElPaso.HTTP.Server` (439 líneas) ⚠️

**Función**: Servidor HTTP Plug.Router con endpoints API.

**Problemas:**

| ID | Severidad | Descripción | Línea |
|----|-----------|-------------|-------|
| SRV-01 | HIGH | `verify_admin_auth` extrae el token del header pero no **verifica el rol en los claims del JWT**. El match `%{role: :admin}` solo matchea si el claim `role` es exactamente `:admin`, pero `verify_token` retorna el role como atom. Si el token tiene `"role": "admin"`, se convierte a `:admin` y funciona. Pero no hay validación adicional de que el usuario exista en BD. | 226-239 |
| SRV-02 | MEDIUM | Endpoints `/infer`, `/models/status`, `/route` son placeholders que devuelven JSON dummy. No implementados. | 88-92, 242-253 |
| SRV-03 | MEDIUM | `generate_prometheus_metrics` devuelve métricas hardcodeadas a cero. No reflejan el estado real del sistema. | 262-299 |
| SRV-04 | MEDIUM | No hay middleware de `Plug.Parsers` para parsear automáticamente el body JSON. Cada endpoint hace `read_body` + `Jason.decode` manualmente. | 34-35 |
| SRV-05 | LOW | `send_chunk_data` accede a `conn.adapter` que es parte interna de Plug. Frágil ante cambios de API de Plug. | 430-437 |
| SRV-06 | LOW | El endpoint `/v1/chat/ws` devuelve un JSON diciendo "websocket ready" pero no implementa WebSocket real. Es publicidad engañosa. | 26-29 |

### 4.7 `ElPaso.Domain.RouterAnalyzer` (249 líneas) ✅

**Función**: Análisis de tendencias con regresión lineal y detección de retries.

**Evaluación**: Es uno de los módulos mejor implementados. La regresión lineal es correcta, el agrupamiento por ventanas semanales funciona, y la detección de retries (< 10s entre mensajes misma sesión) es razonable.

**Problemas menores:**

| ID | Severidad | Descripción | Línea |
|----|-----------|-------------|-------|
| RTA-01 | LOW | `split_into_weekly_windows` asume que las decisiones están dentro de un rango de fechas continuo. Si hay gaps grandes, las ventanas pueden estar vacías. | 90-113 |
| RTA-02 | LOW | `success_rate` considera "retry" como no-éxito, pero no distingue entre "error", "timeout", y "retry". | 116-123 |

### 4.8 `ElPaso.Security.JWT` (109 líneas) ⚠️

| ID | Severidad | Descripción | Línea |
|----|-----------|-------------|-------|
| JWT-01 | **CRITICAL** | `get_secret()` tiene un fallback hardcodeado: `"dev-secret-change-in-prod"`. Si no se configura `ELPASO_JWT_SECRET` ni `:elpaso, :jwt_secret`, el secreto por defecto es trivial. **Esto compromete toda la autenticación en producción.** | 106-108 |
| JWT-02 | HIGH | `generate_token` hace `raise "Error generando token"` si JOSE falla. Un `raise` en un endpoint HTTP crashea el proceso Cowboy. Debería retornar `{:error, ...}`. | 44 |
| JWT-03 | MEDIUM | `extract_from_conn` usa `Regex.replace` en cada request para quitar "Bearer ". Mejor usar pattern matching: `"Bearer " <> token = auth_header`. | 93-98 |
| JWT-04 | LOW | `verify_token` compara `DateTime.to_unix` del momento actual con el `exp` del token. Hay riesgo de race condition si el token expira entre la verificación y el uso. Es aceptable para el TTL de 24h. | 64-66 |

### 4.9 `ElPaso.Security.RateLimiter` (30 líneas) ⚠️

| ID | Severidad | Descripción | Línea |
|----|-----------|-------------|-------|
| RL-01 | HIGH | **Race condition**: El cálculo de refill (`elapsed_minutes * max_rpm`) usa aritmética de punto flotante que puede causar imprecisión. Además, entre el `lookup` y el `insert` hay una ventana de race condition: dos procesos pueden leer el mismo estado y ambos creer que tienen tokens. | 9-24 |
| RL-02 | MEDIUM | No hay limpieza de entradas antiguas en la tabla ETS. La tabla crecerá indefinidamente con usuarios que ya no están activos. | N/A |
| RL-03 | MEDIUM | `init()` crea la tabla como `:public`. Cualquier proceso puede manipular los contadores. Debería ser `:protected`. | 29 |

### 4.10 `ElPaso.Domain.AutoTuner` (205 líneas) ✅

**Función**: GenServer que ejecuta auto-tuning periódico del router.

**Evaluación**: Buena implementación. Usa `handle_continue` para trabajo async, programa siguiente ejecución con `Process.send_after`, y soporta revert.

**Problemas menores:**

| ID | Severidad | Descripción | Línea |
|----|-----------|-------------|-------|
| AT-01 | MEDIUM | Si `Process.send_after` falla (por ej. memoria), el auto-tune deja de ejecutarse para siempre. Debería haber un mecanismo de retry. | 203 |
| AT-02 | LOW | `handle_info(:run_auto_tune)` llama a `do_auto_tune` directamente sin manejar el caso de que el proceso esté ocupado (ya ejecutándose). Podría causar ejecuciones solapadas. | 54-56 |

### 4.11 `ElPaso.Engine.Adapter` (222 líneas) ✅

**Función**: Dispatch a adaptadores HTTP según el tipo de engine.

Bien estructurado. El dispatch es limpio y los adaptadores delegan correctamente en HTTPClient.

### 4.12 `ElPaso.Engine.Dispatcher` (26 líneas) ⚠️

| ID | Severidad | Descripción | Línea |
|----|-----------|-------------|-------|
| DSP-01 | HIGH | `determine_model` retorna hardcoded `"default_model"`. Esto significa que el dispatcher ignora completamente el routing y siempre intenta usar un modelo que probablemente no existe. Es un **stub no implementado**. | 22-25 |

### 4.13 `ElPaso.Domain.EngineManager` (103 líneas) ⚠️

| ID | Severidad | Descripción | Línea |
|----|-----------|-------------|-------|
| EM-01 | HIGH | `test_engine` usa `:httpc.request` (cliente HTTP de Erlang, síncrono y bloqueante) en lugar de Finch. Esto bloquea el proceso que llama y no respeta el pool de conexiones de la aplicación. | 71 |
| EM-02 | MEDIUM | `health_url` para adapters no-ollama asume `/v1/models` como endpoint de health. OpenAI no tiene ese endpoint; Anthropic tiene `/v1/messages` pero requiere auth. | 91-95 |

### 4.14 `ElPaso.Cluster.NodeRegistry` (169 líneas) ⚠️

| ID | Severidad | Descripción | Línea |
|----|-----------|-------------|-------|
| CLU-01 | MEDIUM | `handle_call(:all_model_states)` retorna `%{}` vacío. Es un stub. La funcionalidad de agregación de estados de cluster no está implementada en el NodeRegistry. | 119-123 |
| CLU-02 | LOW | La conversión de `String.to_atom(node_name)` en `init` puede causar atom table DoS si el nombre de nodo viene de input no confiable. | 81 |
| CLU-03 | LOW | `connect_to_configured_nodes` no se llama periódicamente; solo al inicio. Si un nodo se añade después, no se conecta. | 154 |

### 4.15 `ElPaso.ModelDownloader` (238 líneas) ⚠️

| ID | Severidad | Descripción | Línea |
|----|-----------|-------------|-------|
| DL-01 | MEDIUM | `do_download` usa `Finch.stream` con `ElPasoFinch` (sin punto), que es un átomo diferente a `ElPaso.Finch`. **Probable bug tipográfico** — la pool de Finch configurada es `ElPaso.Finch`. | 112 |
| DL-02 | MEDIUM | `@download_dir` se evalúa en compile-time con `Application.compile_env`. Si el home directory cambia entre compilación y ejecución, el path será incorrecto. | 7 |
| DL-03 | LOW | El archivo temporal se limpia con `File.rm` en caso de error de checksum, pero no en caso de otros errores HTTP. | 145-147 |

### 4.16 `ElPaso.Context.Storage` (315 líneas) ✅

Buena implementación del patrón Repository sobre Ecto. Queries parametrizadas, sin SQL injection. El upsert de api_usage está bien hecho con `on_conflict`.

**Problema menor:**

| ID | Severidad | Descripción | Línea |
|----|-----------|-------------|-------|
| STO-01 | LOW | `get_model_pricing` tiene hardcodeados precios de Claude (opus $15/$75, sonnet $3/$15, haiku $0.25/$1.25). Si se añaden más modelos, hay que modificar código. Debería usar la tabla `model_pricing`. | 186-193 |

### 4.17 Schemas Ecto (12 archivos) ✅

Todos los schemas están correctamente implementados con:
- `@primary_key {:id, :binary_id, autogenerate: true}` para UUIDs
- `changeset/2` con validaciones apropiadas
- `unique_constraint` en nombres
- `timestamps()` con `inserted_at: :created_at`

**Problema menor:**
- `ApiUsage` y `AutoTuneRun` usan `@primary_key false` pero no definen una PK compuesta. La migración `api_usage` tiene `unique_index([:user_id, :model_id, :date])` que actúa como PK lógica.

---

## 5. AUDITORÍA DE SEGURIDAD (OWASP Top 10)

### 5.1 A01 — Broken Access Control 🔴

| Hallazgo | Severidad | Ubicación |
|----------|-----------|-----------|
| `verify_admin_auth` solo verifica que el claim `role` sea `:admin`. No verifica que el usuario exista en BD ni que esté activo. | HIGH | `lib/el_paso/http/server.ex:226-239` |
| Endpoints admin (`/admin/*`) no están protegidos por rate limiting. Un atacante puede hacer fuerza bruta de tokens JWT. | MEDIUM | `lib/el_paso/http/server.ex:155-223` |
| No hay control de acceso a nivel de recurso (IDOR): cualquier admin puede ver sesiones y usage de cualquier usuario. | MEDIUM | `lib/el_paso/context/storage.ex` |

### 5.2 A02 — Cryptographic Failures 🔴

| Hallazgo | Severidad | Ubicación |
|----------|-----------|-----------|
| **JWT secret por defecto hardcodeado**: `"dev-secret-change-in-prod"`. Permite a cualquiera generar tokens válidos si no se configura. | **CRITICAL** | `lib/el_paso/security/jwt.ex:107` |
| API keys almacenadas en texto plano en la BD (campo `api_key` en engines, models). | MEDIUM | `lib/el_paso/models/engine.ex:14` |
| No se usa `:crypto.hash` para hashear API keys de usuarios. Campo `api_key_hash` existe en schema `User` pero no se usa en auth. | MEDIUM | `lib/el_paso/models/user.ex:12` |
| JWT usa HS256 (simétrico). Para producción multi-nodo sería preferible RS256 (asimétrico). | LOW | `lib/el_paso/security/jwt.ex:37` |

### 5.3 A03 — Injection 🔴

| Hallazgo | Severidad | Ubicación |
|----------|-----------|-----------|
| **SQL Injection en `handle_db(["create"])`**: `"CREATE DATABASE #{db_name}"`. El nombre de BD viene de `DATABASE_URL` que puede ser manipulado. | **CRITICAL** | `lib/el_paso/cli.ex:527` |
| `verify_admin_auth` usa `Regex.replace` con input del header `Authorization`. Aunque no es injection directa, es frágil. | LOW | `lib/el_paso/http/server.ex:229` |

### 5.4 A04 — Insecure Design 🔴

| Hallazgo | Severidad | Ubicación |
|----------|-----------|-----------|
| El rate limiter no se aplica a los endpoints de autenticación (`/auth/token`) ni admin. | HIGH | `lib/el_paso/security/rate_limiter.ex` |
| No hay límite en el número de sesiones por usuario. Un atacante puede crear sesiones ilimitadas. | MEDIUM | `lib/el_paso/context/storage.ex:17` |
| No hay validación del tamaño del body en POST endpoints. Un atacante puede enviar payloads enormes. | MEDIUM | `lib/el_paso/http/server.ex` |

### 5.5 A05 — Security Misconfiguration 🔴

| Hallazgo | Severidad | Ubicación |
|----------|-----------|-----------|
| `config/prod.exs` tiene `jwt_secret: "change-me-in-production"` como fallback. | HIGH | `config/prod.exs:21` |
| `config/dev.exs` expone `show_sensitive_data_on_connection_error: true` y `stacktrace: true`. | LOW | `config/dev.exs:22-23` |
| No se configuran security headers HTTP (CSP, HSTS, X-Frame-Options, X-Content-Type-Options). | MEDIUM | `lib/el_paso/http/server.ex` |
| No hay `Plug.SSL` para forzar HTTPS en producción. | MEDIUM | `lib/el_paso/http/server.ex` |

### 5.6 A06 — Vulnerable Components 🔴

| Hallazgo | Severidad | Ubicación |
|----------|-----------|-----------|
| Dependencias locales (`zaguan`, `batamanta`) sin versionado explícito. Cualquier cambio en ellas puede romper ElPaso. | MEDIUM | `mix.exs:74,83` |
| No se ejecuta `mix hex.audit` regularmente para verificar dependencias. | LOW | N/A |

### 5.7 A07 — Auth Failures 🔴

| Hallazgo | Severidad | Ubicación |
|----------|-----------|-----------|
| `valid_api_key?` compara contra API key global (`Application.get_env(:elpaso, :inference_api_key)`) y no contra la BD de usuarios. La tabla `users` existe pero no se usa para autenticación. | HIGH | `lib/el_paso/security/auth.ex:37-39` |
| JWT tiene TTL de 24h sin refresh token. Si un token se ve comprometido, el atacante tiene 24h de acceso. | MEDIUM | `lib/el_paso/security/jwt.ex:9` |
| No hay protección contra fuerza bruta en `/auth/token`. | MEDIUM | `lib/el_paso/http/server.ex:123-152` |

### 5.8 A08 — Data Integrity Failures 🟡

No se encontraron issues críticos. Los changesets de Ecto protegen la integridad de datos en escritura.

### 5.9 A09 — Logging Failures 🔴

| Hallazgo | Severidad | Ubicación |
|----------|-----------|-----------|
| `Logger.error` en varios lugares podría loguear `inspect(reason)` que contiene partes del request/response con API keys. | HIGH | Múltiples ubicaciones |
| No hay log de auditoría para operaciones administrativas (crear/eliminar modelos, cambios de config). | MEDIUM | N/A |

### 5.10 A10 — SSRF 🟡

| Hallazgo | Severidad | Ubicación |
|----------|-----------|-----------|
| `HTTPClient` no valida las URLs antes de hacer requests. Si un engine se configura con `base_url` maliciosa, Finch podría conectar a hosts internos. | MEDIUM | `lib/el_paso/engine/http_client.ex` |
| `ModelDownloader` descarga de URLs construidas con `repo_id` de input de usuario sin validar el destino. | LOW | `lib/el_paso/downloader/model_downloader.ex:171-172` |

### 5.11 Resumen de Seguridad

```
CRÍTICOS:  2  (JWT secret hardcodeado, SQL Injection en DB create)
HIGH:      8  (Access control, auth bypass, config insegura, logging, rate limiting)
MEDIUM:   12  (Headers, SSRF, componentes, secrets en texto plano)
LOW:       5
```

**Score de seguridad: 35/100** — El proyecto NO está listo para producción desde el punto de vista de seguridad.

---

## 6. AUDITORÍA DE PERFORMANCE

### 6.1 Cuellos de Botella Identificados

| ID | Problema | Impacto | Ubicación |
|----|----------|---------|-----------|
| PERF-01 | **ModelManager GenServer serializa todas las inferencias**. Un solo `GenServer.call` bloquea todas las requests concurrentes. | **CRITICAL** | `lib/el_paso/domain/model_manager.ex:68-103` |
| PERF-02 | `Router.select_model` llama a `Repo.all(Model)` en cada request. Para N modelos = query SQL por request. | HIGH | `lib/el_paso/domain/router.ex:28` |
| PERF-03 | `do_infer` hace `Repo.get(Engine, ...)` en cada inferencia. Si hay 100 requests/minuto, son 100 queries extra. | MEDIUM | `lib/el_paso/domain/model_manager.ex:108-112` |
| PERF-04 | `handle_engine(["show"])` usa `Enum.find` sobre `list_engines()` en lugar de query indexada por nombre. | MEDIUM | `lib/el_paso/cli.ex:830` |
| PERF-05 | `generate_prometheus_metrics` no refleja métricas reales. Los dashboards de Prometheus mostrarán datos falsos. | MEDIUM | `lib/el_paso/http/server.ex:262-299` |
| PERF-06 | `:httpc.request` en `EngineManager.test_engine` es bloqueante y lento comparado con Finch. | LOW | `lib/el_paso/domain/engine_manager.ex:71` |

### 6.2 Recomendaciones de Optimización

1. **Desacoplar ModelManager**: Mover la inferencia a un `Task` supervisado o usar un `:pool` de workers en lugar de serializar vía GenServer.
2. **Cachear modelos en ETS**: El estado de modelos debe estar en ETS (`:protected`, `read_concurrency: true`) y refrescarse solo cuando cambia.
3. **Eager loading de Engine**: Cargar `engine` vía `Repo.preload` en `list_models()` para evitar N+1 queries.
4. **Métricas reales**: Conectar `Telemetry.Store` a los eventos de telemetry emitidos por el pipeline de inferencia.

---

## 7. AUDITORÍA DE CONCURRENCIA

### 7.1 Race Conditions

| ID | Descripción | Severidad | Ubicación |
|----|-------------|-----------|-----------|
| CNC-01 | `RateLimiter.check_rate` tiene race condition en el patrón read-check-write: entre `ets:lookup` y `ets:insert`, otro proceso puede modificar el bucket. | HIGH | `lib/el_paso/security/rate_limiter.ex:9-24` |
| CNC-02 | `Config.Loader.update_affinity` escribe en ETS y luego en archivo. Si dos procesos actualizan la misma affinity, la segunda escritura en archivo sobrescribe la primera **sin considerar el valor actual en ETS**. | MEDIUM | `lib/el_paso/config.ex:198-219` |
| CNC-03 | `ModelDownloaderRegistry` usa ETS `:public`. Múltiples procesos pueden registrar/actualizar el mismo download_id concurrentemente sin coordinación. | LOW | `lib/el_paso/downloader/model_downloader.ex:206-237` |

### 7.2 Deadlocks Potenciales

| ID | Descripción | Severidad |
|----|-------------|-----------|
| CNC-04 | `ModelManager.infer` → `GenServer.call` → dentro del handler se llama a `Zaguan.Engine.CircuitBreaker.call` que a su vez llama al callback que hace `Repo.get`. Si el Repo tiene un deadlock de conexión de pool, el GenServer queda bloqueado para siempre. | MEDIUM |

### 7.3 ETS Usage Review

| Tabla | Tipo | Acceso | Problema |
|-------|------|--------|----------|
| `:rate_limiter` | `:set`, `:public` | Lectura/escritura concurrente | **Debe ser `:protected`**. Cualquier proceso puede manipularlo. |
| `:affinity_table` | `:set`, `:public`, `read_concurrency: true` | Alta lectura, baja escritura | `:protected` sería más seguro. |
| `:model_downloads` | `:set`, `:public` | Baja frecuencia | `:protected` recomendado. |

---

## 8. CALIDAD DE CÓDIGO ELIXIR

### 8.1 Code Smells Detectados

| ID | Descripción | Ubicación |
|----|-------------|-----------|
| SML-01 | **`rescue` genérico con `_ ->`**: Enmascara errores reales. Usado en `ModelManager.init`, `CLI.handle_router`, `CLI.handle_cluster`. | Múltiple |
| SML-02 | **Funciones de más de 30 líneas**: `CLI.main/1` (411 líneas la función `main(args)` sin contar helpers). `handle_server(["start"])` con 80 líneas. | `lib/el_paso/cli.ex` |
| SML-03 | **Código duplicado**: `handle_profile(["add"])`, `handle_model(["add"])`, `handle_engine(["add"])` tienen estructura casi idéntica. | `lib/el_paso/cli.ex` |
| SML-04 | **`String.to_atom` con input externo**: En `CLI.handle_cluster(["join"])`, el nombre del nodo se convierte a átomo con `String.to_atom`. En Elixir, los átomos no se garbage-collectan. Un atacante que controle `--nodes` puede hacer atom table DoS. | `lib/el_paso/cli.ex:1450` |
| SML-05 | **Variables no utilizadas**: `_env_port` en `Config.Loader.get` (línea 47). `# events` comentado en `generate_prometheus_metrics` (línea 264). | Múltiple |
| SML-06 | **`raise` para control de flujo**: `Config.Loader.get` usa `raise` si faltan env vars en producción. En Elixir idiomático, debería retornar `{:error, reason}`. | `lib/el_paso/config.ex:67` |
| SML-07 | **Dead code**: `Config.Loader.ref/1` definido pero nunca invocado. `ElPaso.Engine` behaviour definido pero ningún adapter lo implementa (usan funciones planas). | `lib/el_paso/config.ex:31-33`, `lib/el_paso/engine.ex` |
| SML-08 | **Typos en mensajes de usuario**: `"elapso cluster --help"` (debe ser "elpaso"), `"elpasar bench run"` (debe ser "elpaso"). | `lib/el_paso/cli.ex:64,282` |
| SML-09 | **Comentarios en español mezclados con código en inglés**: `# 兼容 con formato` (mezcla chino, español). `# Muy importante: localhost, no la IP del contenedor`. | Múltiple |
| SML-10 | **`import Plug.Conn` a nivel módulo**: En `ElPaso.Security.JWT` se importa `Plug.Conn` pero solo se usa una función. Mejor usar `alias Plug.Conn` o llamada completa. | `lib/el_paso/security/jwt.ex:7` |

### 8.2 Convenciones de Nombrado

| Evaluación | ✅/⚠️ |
|------------|-------|
| Módulos en snake_case con namespace | ✅ |
| Funciones públicas documentadas con `@doc` | ✅ (mayoría) |
| Typespecs en funciones clave | ⚠️ (inconsistentes — Router sí, CLI no) |
| Archivos de test reflejan estructura de `lib/` | ✅ |
| Schemas en `Models` vs `Context.Schemas` | ⚠️ — división confusa (ver abajo) |

**Nota arquitectónica**: La separación entre `ElPaso.Models` (engines, models, users, etc.) y `ElPaso.Context.Schemas` (sessions, messages, routing_decisions) es inconsistente. Las entidades "core" están en `Models` y las "operacionales" en `Schemas`, pero no hay un criterio claro. Sería más limpio unificar bajo `ElPaso.Schemas` o usar `ElPaso.Core.Schemas` vs `ElPaso.Context.Schemas`.

### 8.3 Uso de Pattern Matching

| Evaluación | ✅/⚠️ |
|------------|-------|
| `case`/`with` en lugar de `if` anidados | ✅ |
| Pattern matching en firmas de función | ⚠️ (poco usado — `CLI.main` usa guards de lista pero no extrae variables) |
| Tuplas `{:ok, _}` / `{:error, _}` | ✅ |
| `cond` para lógica multi-condición | ✅ (pero a veces excesivo) |

---

## 9. GESTIÓN DE CONFIGURACIÓN

### 9.1 Fuentes de Configuración (en orden de prioridad)

1. Variables de entorno (máxima prioridad)
2. Archivo INI `~/.config/elpaso/elpaso.conf`
3. Valores por defecto en código

### 9.2 Problemas de Configuración

| ID | Descripción | Severidad |
|----|-------------|-----------|
| CFG-07 | **Configuración duplicada**: `runtime.exs` y `prod.exs` definen configuraciones solapadas (DB, http_port, etc.). `runtime.exs` se ejecuta después y puede sobrescribir valores de `prod.exs`. | HIGH |
| CFG-08 | `runtime.exs` tiene valores hardcodeados para modelos "fast" y "heavy" que contradicen la filosofía de "todo por CLI/DB". Este archivo es una reliquia de desarrollo. | HIGH |
| CFG-09 | `config.exs` repite `import Config` (línea 2 en `runtime.exs`). | LOW |
| CFG-10 | No hay validación de configuración al arranque (schema validation). NimbleOptions está en dependencias pero no se usa para validar config. | MEDIUM |

---

## 10. BASE DE DATOS Y ESQUEMA

### 10.1 Migraciones

Dos migraciones:

1. **`20240101000000_create_initial_tables.exs`**: Crea `engines`, `models`, `personalities`, `profiles`, `users`. Bien estructurada, con índices únicos y FK references.
2. **`20240421_initial_setup.exs`**: Crea `sessions`, `messages`, `conversation_summaries`, `routing_decisions`, `auto_tune_runs`, `api_usage`, `model_pricing`, `sessions_shared`.

### 10.2 Evaluación del Esquema

**✅ Aciertos:**
- UUIDs como PKs en tablas principales
- Índices compuestos en `routing_decisions` para queries analíticos
- `on_delete: :nilify_all` en FKs para evitar eliminación en cascada accidental
- `unique_index` en `api_usage` para upsert correcto
- Timestamps en todas las tablas
- `collate: "C"` en columnas `name` para búsquedas exactas

**⚠️ Problemas:**

| ID | Descripción | Severidad |
|----|-------------|-----------|
| DB-01 | Tabla `sessions` usa `session_id` como PK pero sin constraint `primary_key: true`. No hay garantía de unicidad a nivel DB (solo índice). | MEDIUM |
| DB-02 | `messages` no tiene FK a `sessions.session_id`. Un mensaje puede apuntar a una sesión inexistente. | MEDIUM |
| DB-03 | `routing_decisions` y `auto_tune_runs` no tienen PK definida. Ecto schemas usan `@primary_key false`, lo cual funciona pero no es ideal para integridad. | MEDIUM |
| DB-04 | No hay `CHECK` constraints para validar valores (ej: `role IN ('user', 'admin')`, `temperature BETWEEN 0 AND 2`). | LOW |

---

## 11. TESTING Y COBERTURA

### 11.1 Estado Actual

| Métrica | Valor |
|---------|-------|
| Archivos de test | 24 |
| Directorios de test vacíos | 6 (`cli/`, `event/`, `examples/`, `models/`, `plugin/`, `storage/`) |
| Cobertura mínima configurada | 70% (threshold) |
| Módulos ignorados en cobertura | 13 (CLI, HTTP.Server, Application, Mix.Tasks, etc.) |

### 11.2 Problemas de Testing

| ID | Descripción | Severidad |
|----|-------------|-----------|
| TST-01 | **El test principal (`el_paso_test.exs`) es trivial**: 2 tests que verifican `hello() == :world` y que la versión es string. **No prueba nada del dominio.** | **CRITICAL** |
| TST-02 | 13 módulos críticos están excluidos de cobertura. Esto incluye `CLI` (1846 líneas), `HTTP.Server` (439 líneas), y `Application`. Significa que el 40% del código no tiene tests. | HIGH |
| TST-03 | No hay tests de integración para los endpoints HTTP. No se prueba el flujo completo request → router → inferencia → respuesta. | HIGH |
| TST-04 | No hay tests de streaming (SSE). La funcionalidad de streaming no está verificada. | MEDIUM |
| TST-05 | `test_helper.exs` no configura `Ecto.Adapters.SQL.Sandbox` correctamente para tests asíncronos. Usa `mode: :auto` que no es compatible con tests concurrentes. | MEDIUM |
| TST-06 | Sin tests de carga/concurrencia para RateLimiter o ModelManager. | LOW |
| TST-07 | Sin tests para el parser INI de `Config.Loader`. | LOW |

### 11.3 Recomendación

El objetivo debe ser:
- **Cobertura > 80% en módulos de dominio** (Router, RouterAnalyzer, AutoTuner, CostManager, Security)
- **Tests de integración HTTP** con `Plug.Test` para todos los endpoints
- **Tests de contrato** para los adaptadores de engine
- **No excluir módulos** de cobertura sin justificación documentada

---

## 12. ISSUES CRÍTICOS (BLOQUEANTES)

Estos **6 issues deben resolverse antes de considerar el proyecto terminado**:

### CRIT-01: SQL Injection en creación de BD
- **Archivo**: `lib/el_paso/cli.ex:527`
- **Código**: `Postgrex.query(conn, "CREATE DATABASE #{db_name}", [])`
- **Fix**: Usar `Postgrex.query(conn, "CREATE DATABASE \"#{String.replace(db_name, "\"", "\"\"")}\"", [])` o, mejor, usar `Ecto.Adapters.SQL` para crear la BD.
- **Alternativa**: Eliminar este comando y usar solo `mix ecto.create`.

### CRIT-02: JWT secret hardcodeado
- **Archivo**: `lib/el_paso/security/jwt.ex:107`
- **Código**: `System.get_env("ELPASO_JWT_SECRET") || Application.get_env(:elpaso, :jwt_secret, "dev-secret-change-in-prod")`
- **Fix**: En producción, **obligar** a que la variable esté definida. Si no lo está, el sistema debe negarse a arrancar.

```elixir
defp get_secret do
  secret = System.get_env("ELPASO_JWT_SECRET") ||
           Application.get_env(:elpaso, :jwt_secret)

  if is_nil(secret) or secret == "dev-secret-change-in-prod" or secret == "change-me-in-production" do
    raise "ELPASO_JWT_SECRET must be set to a strong random value in production"
  end

  secret
end
```

### CRIT-03: Bug de tokens siempre en cero (OpenAI/Anthropic)
- **Archivo**: `lib/el_paso/engine/http_client.ex:52-62 y 111-121`
- **Código**: `Map.get(body, "usage", ...)` en lugar de `Map.get(parsed_response, "usage", ...)`
- **Fix**: Leer `usage` de la respuesta parseada, no del body del request.

```elixir
# En openai_compatible, cambiar:
{:ok, %{"choices" => [%{"message" => message, "finish_reason" => finish}], "usage" => usage}} ->
  {:ok,
   %{
     content: message["content"],
     finish_reason: map_finish_reason(finish),
     prompt_tokens: Map.get(usage, "prompt_tokens", 0),
     completion_tokens: Map.get(usage, "completion_tokens", 0)
   }}
```

### CRIT-04: ModelManager bloquea requests secuencialmente
- **Archivo**: `lib/el_paso/domain/model_manager.ex:68-103`
- **Problema**: `handle_call({:infer, ...})` ejecuta la inferencia HTTP dentro del proceso GenServer, serializando todas las requests.
- **Fix**: Usar `Task.start` o `handle_cast` + respuesta async, o partir el estado por modelo (un GenServer por modelo).

```elixir
# Alternativa: responder inmediatamente y hacer la inferencia async
def handle_call({:infer, model_id, request}, from, state) do
  Task.start(fn ->
    result = do_inference(model_id, request)
    GenServer.reply(from, result)
  end)
  {:noreply, state}
end
```

### CRIT-05: Tests sin valor real
- **Archivo**: `test/el_paso_test.exs`
- **Problema**: El test principal tiene 2 tests triviales que no prueban funcionalidad.
- **Fix**: Escribir tests de integración para los flujos principales: CRUD de modelos, inferencia (mockeada), pipeline Anthropic.

### CRIT-06: Dispatcher es un stub
- **Archivo**: `lib/el_paso/engine/dispatcher.ex:22-25`
- **Problema**: `determine_model` retorna `"default_model"` hardcodeado.
- **Fix**: Integrar con `Router.select_model` o eliminar el módulo si no se usa.

---

## 13. ISSUES DE ALTA PRIORIDAD

Estos **11 issues deben resolverse para considerar el proyecto "production-ready"**:

| ID | Descripción | Archivo |
|----|-------------|---------|
| HIGH-01 | `Config.Loader.get` usa `raise` para control de flujo | `lib/el_paso/config.ex:67` |
| HIGH-02 | Router `detect_task_type` es inútil con heurística actual | `lib/el_paso/domain/router.ex:75` |
| HIGH-03 | `EngineManager.test_engine` usa `:httpc` bloqueante en vez de Finch | `lib/el_paso/domain/engine_manager.ex:71` |
| HIGH-04 | `validate_api_key?` no consulta la tabla `users` | `lib/el_paso/security/auth.ex:37` |
| HIGH-05 | Rate limiter no se aplica a endpoints de auth/admin | `lib/el_paso/security/rate_limiter.ex` |
| HIGH-06 | Rate limiter tiene race condition en refill | `lib/el_paso/security/rate_limiter.ex:9-24` |
| HIGH-07 | `runtime.exs` tiene config hardcodeada de modelos | `config/runtime.exs:21-63` |
| HIGH-08 | Sin security headers HTTP (CSP, HSTS) | `lib/el_paso/http/server.ex` |
| HIGH-09 | `Logger.error` puede loguear API keys vía `inspect` | Múltiple |
| HIGH-10 | `handle_db(["create"])` usa interpolación SQL (CRIT-01) | `lib/el_paso/cli.ex:527` |
| HIGH-11 | `ransform_messages_for_anthropic` no usa el campo `system` de Anthropic | `lib/el_paso/engine/http_client.ex:322` |

---

## 14. ISSUES DE MEDIA PRIORIDAD

10 issues que deben resolverse en la siguiente iteración:

| ID | Descripción |
|----|-------------|
| MED-01 | Añadir `Plug.Parsers` al pipeline HTTP en lugar de `read_body` manual |
| MED-02 | ETS tables deben ser `:protected` en lugar de `:public` |
| MED-03 | `ModelDownloader` usa `ElPasoFinch` (sin punto) en vez de `ElPaso.Finch` |
| MED-04 | `generate_prometheus_metrics` devuelve métricas hardcodeadas |
| MED-05 | Configuración duplicada entre `runtime.exs` y `prod.exs` |
| MED-06 | Sin validación de tamaño de body en POST endpoints |
| MED-07 | Limpiar entradas antiguas de `rate_limiter` ETS |
| MED-08 | Schemas `routing_decisions` y `auto_tune_runs` sin PK definida |
| MED-09 | `messages` sin FK a `sessions` |
| MED-10 | Documentar tipos de retorno en funciones públicas sin `@spec` |

---

## 15. ISSUES DE BAJA PRIORIDAD

6 issues cosméticos o de mejora continua:

| ID | Descripción |
|----|-------------|
| LOW-01 | Errores tipográficos en CLI help text ("elapso", "elpasar") |
| LOW-02 | `Config.Loader.ref/1` es código muerto |
| LOW-03 | `ElPaso.Engine` behaviour definido pero no implementado por adapters |
| LOW-04 | `@download_dir` usa `Application.compile_env` con tilde path |
| LOW-05 | `AutoTuner.handle_info(:run_auto_tune)` no previene ejecuciones solapadas |
| LOW-06 | Unificar `ElPaso.Models` y `ElPaso.Context.Schemas` bajo un naming consistente |

---

## 16. CHECKLIST DE TERMINACIÓN

Para dar el proyecto por **terminado y listo para producción**, cada item debe estar ✅:

### 🔴 Bloqueantes (antes de cualquier release)

- [ ] **CRIT-01**: Arreglar SQL injection en `handle_db(["create"])`
- [ ] **CRIT-02**: Eliminar JWT secret por defecto; requerir env var en producción
- [ ] **CRIT-03**: Arreglar bug de `usage` tokens en HTTPClient (OpenAI + Anthropic)
- [ ] **CRIT-04**: Desacoplar inferencia del GenServer ModelManager (async)
- [ ] **CRIT-05**: Añadir tests de integración reales para flujos principales
- [ ] **CRIT-06**: Implementar `Dispatcher.determine_model` o eliminar el módulo

### 🟠 Alta Prioridad (antes de producción)

- [ ] **HIGH-01**: Cambiar `raise` por `{:error, reason}` en `Config.Loader.get`
- [ ] **HIGH-02**: Mejorar `detect_task_type` con approach basado en embeddings o clasificación
- [ ] **HIGH-03**: Migrar `EngineManager.test_engine` a Finch
- [ ] **HIGH-04**: Conectar `Auth.valid_api_key?` a tabla `users` de BD
- [ ] **HIGH-05**: Aplicar rate limiting a endpoints `/auth/token` y `/admin/*`
- [ ] **HIGH-06**: Arreglar race condition en rate limiter (usar `:ets.update_counter`)
- [ ] **HIGH-07**: Eliminar config hardcodeada de `runtime.exs`
- [ ] **HIGH-08**: Añadir security headers HTTP (HSTS, CSP, X-Content-Type-Options)
- [ ] **HIGH-09**: Sanitizar `Logger.error/info` para no loguear API keys
- [ ] **HIGH-10**: (mismo que CRIT-01)
- [ ] **HIGH-11**: Usar campo `system` nativo de Anthropic en requests

### 🟡 Media Prioridad (antes de v1.0)

- [ ] **MED-01** a **MED-10**: Ver sección 14

### 🟢 Baja Prioridad (mejora continua)

- [ ] **LOW-01** a **LOW-06**: Ver sección 15

### 📊 Testing

- [ ] Cobertura ≥ 80% en módulos de dominio (sin exclusiones)
- [ ] Tests de integración HTTP para todos los endpoints
- [ ] Tests de streaming (SSE)
- [ ] Tests de concurrencia para RateLimiter
- [ ] Test helper configurado correctamente para Sandbox + async

### 🔒 Seguridad

- [ ] `mix hex.audit` sin vulnerabilidades conocidas
- [ ] `mix credo --strict` sin warnings
- [ ] Variables de entorno validadas al arranque (sin defaults inseguros)
- [ ] Secrets fuera del código fuente
- [ ] Security headers configurados en producción

### 📦 Build & Deploy

- [ ] `MIX_ENV=prod mix release` funcional
- [ ] Dockerfile multi-stage (si aplica)
- [ ] Documentación de despliegue actualizada
- [ ] Script de migración de BD para producción

---

## 17. VEREDICTO FINAL

### ¿Puede darse por terminado?

**NO.** El proyecto requiere trabajo sustancial antes de considerarse listo.

### Resumen de Estado

| Área | Completitud | Calidad | Seguridad |
|------|-------------|---------|-----------|
| Arquitectura | 85% | ✅ Buena | — |
| Schemas/DB | 90% | ✅ Bien | ⚠️ FKs faltantes |
| HTTP API | 70% | ⚠️ Placeholders | 🔴 Sin security headers |
| Engines/Adapters | 80% | 🐛 Bug token=0 | ⚠️ SSRF potential |
| Router/AutoTuner | 70% | ⚠️ Heurística inútil | ✅ N/A |
| Auth/Security | 60% | ⚠️ Race condition | 🔴 JWT secret default |
| CLI | 85% | ⚠️ Muy larga | 🔴 SQL injection |
| Testing | 15% | 🔴 Trivial | 🔴 Sin tests reales |
| Configuración | 60% | ⚠️ Duplicada | 🔴 Defaults inseguros |
| Cluster | 50% | ⚠️ Stubs | ✅ N/A |

### Estimación de Esfuerzo Restante

| Categoría | Issues | Esfuerzo estimado |
|-----------|--------|-------------------|
| Críticos | 6 | 3-5 días |
| Alta prioridad | 11 | 5-7 días |
| Media prioridad | 10 | 3-5 días |
| Baja prioridad | 6 | 1-2 días |
| Testing | — | 5-7 días |
| **Total** | **33** | **~3 semanas** |

### Lo que SÍ está bien

1. **Arquitectura OTP sólida**: El árbol de supervisión, los GenServers, y la separación de capas están bien diseñados.
2. **Schemas Ecto completos**: Los 12 schemas están correctamente implementados con validaciones.
3. **Migraciones limpias**: Las dos migraciones crean un esquema de BD bien indexado.
4. **Circuit Breaker integrado**: El uso de Zaguan para tolerancia a fallos es una excelente decisión arquitectónica.
5. **Streaming funcional**: El soporte SSE para Anthropic y OpenAI está implementado (aunque no testeado).
6. **RouterAnalyzer**: El análisis de tendencias con regresión lineal está bien implementado.
7. **CostManager**: La gestión de costes con pricing por modelo y alertas de budget es correcta.
8. **AnthropicProxy**: La conversión bidireccional de formato Anthropic ↔ interno funciona correctamente.

### Recomendación Final

El proyecto tiene **excelentes bases arquitectónicas** pero necesita un **sprint de hardening** enfocado en seguridad, corrección de bugs, y testing antes de poder considerarse productivo. Con ~3 semanas de trabajo enfocado siguiendo este documento, ElPaso puede alcanzar un estado de producción sólido.

---

*Auditoría realizada por Macahan, Arquitecto Universal Supremo. 2026-05-04.*
*"No te digo lo que quieres oír, te digo lo que necesitas saber."*
