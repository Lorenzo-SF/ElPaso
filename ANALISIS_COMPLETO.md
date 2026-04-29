# Bitácora de Análisis Completo - ElPaso v0.1.0

> **Fecha original**: 2026-04-28  
> **Última actualización**: 2026-04-29  
> **Analista**: Macahan  
> **Versión del proyecto**: 0.1.0  
> **Repositorio**: https://github.com/Lorenzo-SF/ElPaso  
> **Dependencias locales**: zaguan (`~/proyectos/zaguan`), batamanta (`~/proyectos/batamanta`)

---

## ⚠️ NOTA DE ESTADO

Este archivo fue escrito el 2026-04-28 como auditoría inicial. Desde entonces se han completado varias tareas:
- ✅ Migraciones de DB creadas (2 archivos)
- ✅ Todos los schemas Ecto implementados (12 schemas)
- ✅ `Context.Storage` conectado a Repo con queries reales
- ✅ `Config.Loader` reescrito con parser INI + env vars

**Para ver el estado actualizado y las tareas pendientes, ver `IMPLEMENTATION_TRACKER.md`.**

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Arquitectura Actual vs Arquitectura Deseada](#2-arquitectura-actual-vs-arquitectura-deseada)
3. [Auditoría por Capa](#3-auditoría-por-capa)
4. [Módulos Implementados (Código Real)](#4-módulos-implementados-código-real)
5. [Módulos Stubs / No Implementados](#5-módulos-stubs--no-implementados)
6. [Análisis de Lagunas Críticas](#6-análisis-de-lagunas-críticas)
7. [Problemas de Diseño y Calidad](#7-problemas-de-diseño-y-calidad)
8. [Integración con Zaguan](#8-integración-con-zaguan)
9. [Integración con Batamanta](#9-integración-con-batamanta)
10. [Plan de Acción Priorizado](#10-plan-de-acción-priorizado)

---

## 1. Resumen Ejecutivo

ElPaso es un proxy multi-modelo LLM escrito en Elixir/Erlang (OTP 28+, Elixir 1.19.5). La idea central es proporcionar un único punto de entrada HTTP que enrute peticiones a diferentes modelos/engines, con gestión de sesiones portables, detección heurística de perfiles, y herramientas CLI para administración.

**Estado actual**: El proyecto tiene una base sólida de arquitectura OTP y muchos módulos con lógica real (router heurístico, auto-tuner, analizador de tendencias, downloader de modelos, JWT, rate limiter, plugin loader, etc.). **Las migraciones de DB existen, los schemas Ecto están implementados, y `Context.Storage` ya conecta a Repo con queries reales.** Pero la CLI sigue siendo mayoritariamente stubs que no persisten datos, el pipeline de inferencia HTTP devuelve respuestas fake, y conceptos clave como perfiles y la integración con Zaguan/Batamanta no están implementados.

**Diagnóstico**: El proyecto está en un estado de "arquitectura avanzada con capa de datos conectada pero CLI y pipeline HTTP incompletos". La base de datos está modelada y accesible vía Ecto, pero los comandos que el usuario final interactúa son simulaciones.

---

## 2. Arquitectura Actual vs Arquitectura Deseada

### 2.1 Arquitectura Deseada (según especificación)

```
┌─────────────────────────────────────────────────────┐
│                    CLI (elpaso)                      │
│  model|engine|personality|profile CRUD              │
│  server start/stop                                  │
│  router stats/bench/context                         │
└──────────────────┬──────────────────────────────────┘
                    │
┌──────────────────▼──────────────────────────────────┐
│            ~/.config/elpaso/elpaso.conf              │
│  (IP, puerto, API key, entorno, log level)          │
└──────────────────┬──────────────────────────────────┘
                    │
┌──────────────────▼──────────────────────────────────┐
│           Base de Datos (PostgreSQL+pgvector)        │
│  modelos, engines, personalidades, perfiles         │
│  sesiones, mensajes, benchmarks, routing            │
│  configuraciones (todo lo "importante")             │
└──────────────────┬──────────────────────────────────┘
                    │
┌──────────────────▼──────────────────────────────────┐
│              ElPaso Proxy Server                     │
│                                                      │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────┐  │
│  │  Request     │  │  Profile     │  │  Session  │  │
│  │  Parser      │→ │  Detector    │→ │  Manager  │  │
│  │ (explicit)   │  │ (heuristic/  │  │ (context) │  │
│  │              │  │  embedding)  │  │           │  │
│  └─────────────┘  └──────┬───────┘  └──────┬────┘  │
│                          │                  │       │
│                   ┌──────▼───────┐  ┌───────▼────┐  │
│                   │  Router      │  │ Context    │  │
│                   │ (heuristic)  │  │ Builder    │  │
│                   └──────┬───────┘  └────────────┘  │
│                          │                          │
│                   ┌──────▼───────┐                  │
│                   │  Engine      │                  │
│                   │  Dispatcher  │                  │
│                   └──────┬───────┘                  │
│                          │                          │
│              ┌───────────┼───────────┐             │
│              ▼           ▼           ▼             │
│         Ollama     OpenAI    Anthropic            │
│         llama.cpp  vLLM      etc.                 │
└─────────────────────────────────────────────────────┘
```

### 2.2 Arquitectura Actual

```
┌─────────────────────────────────────────────────────┐
│                    CLI (elpaso)                      │
│  ❌ Stubs — no conecta a DB                          │
│  ✅ Help text completo                              │
└──────────────────┬──────────────────────────────────┘
                    │
┌──────────────────▼──────────────────────────────────┐
│            ~/.config/elpaso/elpaso.conf              │
│  ✅ Se crea con `mix elpaso init`                    │
│  ✅ Se lee con Config.Loader (parser INI)           │
│  ✅ Env vars ELPASO_* tienen prioridad sobre INI    │
└──────────────────┬──────────────────────────────────┘
                    │
┌──────────────────▼──────────────────────────────────┐
│           Base de Datos (PostgreSQL+pgvector)        │
│  ✅ Migraciones creadas (2 archivos)                │
│  ✅ 12 schemas Ecto implementados                   │
│  ✅ Context.Storage conectado a Repo con queries    │
│  ❌ CLI no usa las migraciones ni los schemas       │
│  ❌ No hay auto-creación de DB                      │
└──────────────────┬──────────────────────────────────┘
                    │
┌──────────────────▼──────────────────────────────────┐
│              ElPaso Proxy Server                     │
│                                                      │
│  ✅ HTTP.Server con Plug.Cowboy                     │
│  ✅ Endpoints: /dashboard, /metrics, /v1/chat/ws     │
│  ✅ /v1/messages (Anthropic), /infer, /status        │
│  ✅ /auth/token (JWT), /admin/* (admin auth)         │
│  ❌ run_anthropic_pipeline() → respuesta fake        │
│  ❌ No hay endpoint /v1/chat/completions (OpenAI)    │
│  ❌ Pipeline: request → parser → fake response       │
│  ❌ Router NUNCA se invoca desde HTTP                │
│                                                      │
│  ✅ Router heurístico con feature extraction         │
│  ✅ AutoTuner GenServer                              │
│  ✅ RouterAnalyzer con trend analysis                │
│  ⚠️ ModelManager.all_states() → carga de DB          │
│  ❌ ModelManager.infer() → stub                      │
│                                                      │
│  ✅ Context.Manager con ETS sessions                 │
│  ✅ PrefixManager GenServer                          │
│  ✅ Context.Builder                                  │
│  ✅ Storage CRUD → Ecto queries reales               │
│  ❌ reload_session() → {:error, :not_found}          │
│  ❌ EmbeddingClient → {:error, :not_configured}      │
└─────────────────────────────────────────────────────┘
```

### 2.3 Brechas Identificadas

| Aspecto | Deseado | Actual | Estado |
|---------|---------|--------|--------|
| **Perfiles** (model+engine+personalidad) | Concepto central | Schema existe, CLI no implementada | 🔴 Crítico |
| **Personalidades** | CRUD completo | Schema existe, CLI stub | 🟡 Parcial |
| **DB persistencia** | Todo en DB | Schemas + Storage conectados ✅ | ✅ Hecho |
| **Config file** | `elpaso.conf` leído | Parser INI + env vars implementado ✅ | ✅ Hecho |
| **CLI → DB** | Comandos CRUD reales | Stubs con IO.puts | 🔴 Crítico |
| **Proxy real** | Pipeline completo | Respuestas fake | 🔴 Crítico |
| **Zaguan** | Usar Zaguan para lo que ya hace | Referencias sueltas en CLI | 🟡 Parcial |
| **Batamanta** | Empaquetado autónomo | Dep `runtime: false` sin integración | 🟡 Parcial |
| **DB auto-create** | CLI crea DB si no existe | No implementado | 🔴 Crítico |
| **Session context portable** | Capas múltiples | ETS + Storage real ✅ | ✅ Hecho |

---

## 3. Auditoría por Capa

### 3.1 Capa de Aplicación (OTP)

**Archivo**: `lib/el_paso/application.ex`

**Implementado correctamente**:
- ✅ Supervisión tree con strategy `:one_for_one`
- ✅ `ElPaso.Repo` como hijo del supervisor principal
- ✅ `ElPaso.Engine.Registry` como hijo del supervisor principal
- ✅ `ElPaso.Domain.ModelManager` como hijo del supervisor principal
- ✅ `Plug.Cowboy` con puerto configurable
- ✅ `ElPaso.Telemetry.Store` como hijo
- ✅ `ElPaso.Event.Supervisor` como hijo
- ✅ `ElPaso.Domain.AutoTuner` como hijo
- ✅ Soporte cluster (gossip + static) condicional
- ✅ RateLimiter.init() y ModelDownloaderRegistry.init() al arrancar

**Problemas**:
- ⚠️ `SessionSupervisor` tiene `children = []` — no supervisa `Context.Manager`
- ⚠️ `SummarizationSupervisor` tiene `children = []` — no supervisa `SummarizationWorker`
- ⚠️ `Event.Supervisor` tiene `children = []` — no maneja eventos reales
- ⚠️ No hay `terminate/2` para cleanup de ETS

### 3.2 Capa de Configuración

**Archivos**: `lib/el_paso/config.ex`, `config/runtime.exs`

**Implementado**:
- ✅ `Config.Loader.get()` lee desde INI + env vars con prioridad correcta
- ✅ Parser INI funcional (secciones, valores, tipos)
- ✅ `http_port()`, `auto_tune_enabled?()`, `daily_usd_limit()`, etc.
- ✅ En dev/test usa valores por defecto para permitir arranque
- ✅ En prod falla si faltan variables requeridas
- ✅ `Config.load_config()` y `save_config()` funcionan con archivo INI

**Problemas**:
- ⚠️ `Config.get_affinity()` y `update_affinity()` son stubs (siempre 0.5 / :ok)
- ⚠️ `runtime.exs` tiene modelos hardcodeados (`fast`, `heavy`) — contradice "todo en DB"
- ⚠️ No hay migración para tabla `model_pricing` (referenciada en seeds pero no en migration principal)

### 3.3 Capa de Datos (DB)

**Archivos**: `lib/el_paso/repo.ex`, `lib/el_paso/context/schemas/*.ex`, `lib/el_paso/models/*.ex`, `priv/repo/migrations/`

**Implementado**:
- ✅ `ElPaso.Repo` con `Ecto.Repo` + Postgres adapter
- ✅ 2 migraciones: `20240101000000_create_initial_tables.exs` y `20240421_initial_setup.exs`
- ✅ Tablas creadas: `engines`, `models`, `personalities`, `profiles`, `sessions`, `messages`, `routing_decisions`, `conversation_summaries`, `api_usage`, `users`, `benchmarks`, `auto_tune_runs`, `model_pricing`, `sessions_shared`
- ✅ pgvector extension + índices IVFFlat para embeddings
- ✅ 12 schemas Ecto con changesets: Session, Message, RoutingDecision, ConversationSummary, Model, Engine, Personality, Profile, User, ApiUsage, Benchmark, AutoTuneRun
- ✅ `Context.Storage` conectado a Repo con queries reales (CRUD completo)

**Problemas**:
- ⚠️ No hay tabla `model_pricing` en migration principal (referenciada en seeds)
- ⚠️ No hay auto-inicialización de DB (crear DB si no existe)
- ⚠️ No hay seed data para engines, models, personalities, profiles

### 3.4 Capa CLI

**Archivos**: `lib/el_paso/cli.ex`, `lib/mix/tasks/elpaso/*.ex`

**Implementado**:
- ✅ CLI principal con routing de comandos (model, engine, personality, config, server, router, bench, context, cluster)
- ✅ Help text completo y bien estructurado para cada comando
- ✅ Mix tasks: `elpaso init`, `elpaso model add/list/remove/start/stop`, `elpaso engine add/list/remove/test`
- ✅ `ElPaso.CLI.Commands.RouterStats` usa `Zaguan.Drawer.Components.{Header, Table}` — integración real con Zaguan

**Problemas**:
- 🔴 **Ningún comando CLI persiste datos en DB**. Todos son simulaciones con IO.puts
- 🔴 `handle_model(["list"])` muestra tabla vacía hardcoded
- 🔴 `handle_model(["add"])` solo imprime help
- 🔴 `handle_engine(["list"])` muestra engines fake
- 🔴 `handle_personality` — todos los handlers son stubs
- 🔴 `handle_server(["start"])` solo imprime nota de que use `mix run --no-halt`
- 🟡 Mix tasks (`model/add.ex`, `model/list.ex`, etc.) son stubs con IO.puts

### 3.5 Capa HTTP/Proxy

**Archivos**: `lib/el_paso/http/server.ex`, `lib/el_paso/http/request_parser.ex`, `lib/el_paso/http/anthropic/proxy.ex`

**Implementado**:
- ✅ `ElPaso.HTTP.Server` con Plug.Router
- ✅ Endpoints: `/dashboard`, `/metrics`, `/v1/chat/ws`, `/v1/messages`, `/v1/messages_stream`, `/infer`, `/status`, `/auth/token`, `/admin/*`
- ✅ `RequestParser.parse_chat_request()` extrae overrides de sesión del campo `elpaso` en el request
- ✅ `SessionOverrides` struct con: session_id, context_mode, window_size, force_model, latency_tolerance_ms, summarize_with_model
- ✅ `AnthropicProxy.from_anthropic()` convierte formato Anthropic → interno
- ✅ `AnthropicProxy.to_anthropic()` convierte interno → formato Anthropic
- ✅ Streaming con SSE para Anthropic
- ✅ AuthPlug y AdminAuthPlug implementados
- ✅ Dashboard HTML con polling AJAX

**Problemas graves**:
- 🔴 **`run_anthropic_pipeline()` devuelve respuesta fake**: `"Response to: #{prompt}"` — NO llama al router, NO invoca engines
- 🔴 `run_anthropic_stream()` simula streaming con palabras del prompt — NO es real
- 🔴 Endpoint `/v1/chat/completions` (OpenAI compatible) **NO existe** — solo hay `/v1/messages` (Anthropic) y `/infer` (genérico)
- 🔴 Endpoint `/route` y `/models/status` devuelven mensajes genéricos
- 🔴 No hay pipeline real: request → parser → router → engine → response

### 3.6 Capa de Router y Enrutamiento

**Archivos**: `lib/el_paso/domain/router.ex`, `lib/el_paso/domain/router_analyzer.ex`, `lib/el_paso/domain/auto_tuner.ex`

**Implementado (esto es código real y funcional)**:
- ✅ `Router.route(request_id, session_id, user_message, overrides)` — punto de entrada principal
- ✅ `FeatureVector` con: token_estimate, task_type, complexity_score, language, has_structured_output_request, is_continuation, prompt_length_chars, has_image_input, image_count
- ✅ `ModelState` con: model_id, status, current_queue_depth, avg_latency_ms, last_error_at, consecutive_errors, ram_mb, node
- ✅ `RoutingDecision` con: request_id, session_id, selected_model, runner_up, features, scores, reason, decided_at, decision_latency_us
- ✅ `extract_features()` — feature extraction del prompt
- ✅ `detect_task_type()` — heurística por keywords (code, reasoning, summarization, etc.)
- ✅ `calculate_complexity_score()` — multi-señal (tokens, task affinity, sentence depth, vocabulary density, questions)
- ✅ `calculate_scores()` — scoring por modelo con: fit_score, cold_start_penalty, queue_penalty, error_penalty
- ✅ `select_best_model()` — max score selection
- ✅ `record_outcome()` — notifica resultados al router
- ✅ `RouterAnalyzer.analyze_trends()` — análisis de tendencias con linear regression
- ✅ `RouterAnalyzer.alerts()` — combinaciones que requieren alerta
- ✅ `AutoTuner` GenServer con schedule periódico, apply suggestions, revert last

**Problemas**:
- ⚠️ `ModelManager.all_states()` carga de DB pero `infer()` es stub → router no tiene datos reales para scoring
- ⚠️ `Storage.save_routing_decision()` y `update_routing_outcome()` son queries Ecto reales ✅ (ya no son stubs)
- ⚠️ `fit_score()` accede a `model_state.routing_config.task_affinity` — ModelState sí tiene routing_config ✅ (ya corregido en ModelManager)
- ⚠️ `cold_start_penalty()` accede a `model_state.cold_start_estimate_ms` — ModelState sí tiene ese campo ✅

### 3.7 Capa de Contexto y Sesiones

**Archivos**: `lib/el_paso/context/manager.ex`, `lib/el_paso/context/storage.ex`, `lib/el_paso/context/builder.ex`, `lib/el_paso/context/prefix_manager.ex`

**Implementado**:
- ✅ `Context.Manager` GenServer con ETS para session states en memoria
- ✅ `get_or_create_session()` — crea sesión en ETS + Storage si no existe
- ✅ `get_session_state()` — con TTL de 30s en modo cluster
- ✅ `update_session_state()` — actualiza timestamp para TTL
- ✅ `expire_session()` — limpia ETS
- ✅ `list_sessions_by_user()` — filtrado por prefijo de user_id
- ✅ `maybe_prefix_session_id()` — aislamiento entre usuarios
- ✅ `Context.Storage` — **CRUD completo con Ecto queries reales** (ya no son stubs)
- ✅ `Context.Builder.build()` — ensambla prompt con capas (prefix, summary, semantic, window)
- ✅ `Context.PrefixManager` GenServer con ETS para bloques canónicos
- ✅ `build_prefix_content()` — system prompt + capabilities + references

**Problemas**:
- ⚠️ `reload_session()` siempre devuelve `{:error, :not_found}` — nunca recarga desde DB (aunque Storage.get_session() funciona)
- ⚠️ `Context.SessionSupervisor` tiene `children = []` — no supervisa Manager
- ⚠️ `SummarizationWorker` y `SummarizationSupervisor` son stubs vacíos
- ⚠️ `Tokenizer.count()` siempre hace fallback a estimación simple
- ⚠️ `EmbeddingClient.embed()` siempre devuelve `{:error, :not_configured}`

### 3.8 Capa de Engines

**Archivos**: `lib/el_paso/engine.ex`, `lib/el_paso/engine/dispatcher.ex`, `lib/el_paso/engine/registry.ex`, `lib/el_paso/engine/ollama.ex`

**Implementado**:
- ✅ `ElPaso.Engine` behaviour con callbacks: name(), type(), infer(), stream(), prepare_prefix(), health_check(), format_messages()
- ✅ `ElPaso.Engine.Response` struct
- ✅ `ElPaso.Engine.Chunk` struct para streaming
- ✅ `Engine.Registry` GenServer con ETS — register, get, list_all, unregister
- ✅ `Engine.Ollama.new()` y `infer()` — stub funcional
- ✅ `Engine.ChatTemplate.format_message()`, `format_messages()`, `build_prompt()`
- ✅ `Plugin.Loader.load_engine_plugin()` — carga dinámica de plugins desde disco
- ✅ `Engine.Plugin.Echo` — plugin de ejemplo completo e implementado

**Problemas**:
- 🔴 `Engine.Dispatcher.dispatch()` llama a `determine_model()` que siempre devuelve `"default_model"`
- 🔴 `ModelManager.infer()` es stub → `{:error, :not_implemented}` (ahora devuelve respuesta fake del modelo)
- 🔴 No hay adaptador para OpenAI, Anthropic, vLLM, llama.cpp — solo Ollama (stub) y Echo (plugin)
- 🔴 No hay integración real entre Router → Dispatcher → Engine

### 3.9 Capa de Seguridad

**Archivos**: `lib/el_paso/security/auth.ex`, `lib/el_paso/security/jwt.ex`, `lib/el_paso/security/rate_limiter.ex`

**Implementado (código real y funcional)**:
- ✅ `Auth.authenticate()` — verifica API key contra config
- ✅ `Auth.valid_api_key?()` — para endpoint /auth/token
- ✅ `Auth.extract_api_key(conn)` — extrae de header Authorization
- ✅ `JWT.generate_token(user_id, role)` — firma HS256 con JOSE
- ✅ `JWT.verify_token()` — verifica firma y expiración
- ✅ `JWT.extract_from_conn(conn)` — extrae de header
- ✅ `RateLimiter.check_rate()` — token bucket en ETS
- ✅ `RateLimiter.init()` — crea tabla ETS al arrancar

**Problemas**:
- ⚠️ `Auth` usa lista de usuarios hardcoded en config — no hay tabla de usuarios en DB (aunque schema existe)
- ⚠️ JWT secret por defecto: `"dev-secret-change-in-prod"` — riesgo de seguridad

### 3.10 Capa de Telemetría y Costos

**Archivos**: `lib/el_paso/telemetry/store.ex`, `lib/el_paso/cost_manager.ex`

**Implementado (código real)**:
- ✅ `Telemetry.Store` GenServer — suscribe a eventos telemetry, almacena en queue ETS
- ✅ `prefix_cache_hit_ratio()` — ratio de hits
- ✅ `recent_events(n)` — últimos N eventos
- ✅ `CostManager.record_usage()` — registra tokens y calcula coste
- ✅ `CostManager.calculate_cost()` — input/output tokens × precio
- ✅ `CostManager.check_budget()` — verifica budget diario con alertas
- ✅ `CostManager.remote_model_penalty()` — penalización por budget
- ✅ Default pricing para Opus, Sonnet, Haiku

**Problemas**:
- ⚠️ `Storage.upsert_api_usage()` y `daily_spend()` son queries Ecto reales ✅ (ya no son stubs)
- ⚠️ `Storage.get_model_pricing()` devuelve hardcoded — no consulta tabla model_pricing

### 3.11 Capa de Descarga y Storage

**Archivos**: `lib/el_paso/downloader/model_downloader.ex`, `lib/el_paso/storage/s3_adapter.ex`

**Implementado (código real)**:
- ✅ `ModelDownloader.download()` — descarga desde HuggingFace con streaming, progreso, checksum SHA256
- ✅ `ModelDownloader.progress()`, `list_downloads()`, `cancel()`
- ✅ `ModelDownloader.verify_checksum()` — verifica integridad
- ✅ `ModelDownloaderRegistry` ETS para tracking de downloads
- ✅ `S3Adapter.download_model()`, `upload()`, `exists?()`, `download_if_missing()`

**Problemas**:
- ⚠️ `S3Adapter` usa `ExAws.S3` pero no hay config de AWS en runtime.exs
- ⚠️ No hay integración con ModelDownloader en el pipeline de arranque de modelos

### 3.12 Capa de Cluster

**Archivos**: `lib/el_paso/cluster/node_registry.ex`

**Implementado (código real)**:
- ✅ `NodeRegistry` GenServer — registra nodos, conecta a configurados
- ✅ `all_nodes()`, `all_model_states()`, `remote_model_states()` con RPC
- ✅ `node_up()`, `node_down()` casts
- ✅ `net_kernel.start()` con shortnames
- ✅ Soporte gossip + static discovery

**Problemas**:
- ⚠️ `all_model_states()` devuelve `%{}` — no gather estados reales de nodos
- ⚠️ No hay integración con ModelManager para distribuir modelos entre nodos

---

## 4. Módulos Implementados (Código Real)

Estos módulos tienen lógica funcional, no son stubs:

| Módulo | Archivo | Funcionalidad |
|--------|---------|---------------|
| `ElPaso.Domain.Router` | `domain/router.ex` | Router heurístico con feature extraction, scoring, selección |
| `ElPaso.Domain.RouterAnalyzer` | `domain/router_analyzer.ex` | Análisis de tendencias, linear regression, alerts |
| `ElPaso.Domain.AutoTuner` | `domain/auto_tuner.ex` | GenServer auto-tuning periódico, apply/revert suggestions |
| `ElPaso.Security.JWT` | `security/jwt.ex` | Generación/verificación JWT con JOSE |
| `ElPaso.Security.Auth` | `security/auth.ex` | Autenticación API key |
| `ElPaso.Security.RateLimiter` | `security/rate_limiter.ex` | Token bucket en ETS |
| `ElPaso.Telemetry.Store` | `telemetry/store.ex` | Suscripción eventos telemetry, hit ratio |
| `ElPaso.CostManager` | `cost_manager.ex` | Registro uso, cálculo costes, budgets |
| `ElPaso.ModelDownloader` | `downloader/model_downloader.ex` | Descarga HF con streaming, progreso, checksum |
| `ElPaso.Storage.S3Adapter` | `storage/s3_adapter.ex` | Upload/download S3 |
| `ElPaso.Cluster.NodeRegistry` | `cluster/node_registry.ex` | Registro nodos, RPC inter-nodo |
| `ElPaso.Plugin.Loader` | `plugin/loader.ex` | Carga dinámica de plugins |
| `ElPaso.Engine.Plugin.Echo` | `engine/plugin/echo.ex` | Plugin echo completo e implementado |
| `ElPaso.Context.Manager` | `context/manager.ex` | Session states en ETS con TTL cluster |
| `ElPaso.Context.PrefixManager` | `context/prefix_manager.ex` | Bloques canónicos en ETS |
| `ElPaso.Context.Builder` | `context/builder.ex` | Ensamblaje de prompts con capas |
| `ElPaso.Context.Storage` | `context/storage.ex` | **CRUD completo con Ecto queries reales** ✅ |
| `ElPaso.HTTP.AuthPlug` | `http/auth_plug.ex` | Plug autenticación |
| `ElPaso.HTTP.AdminAuthPlug` | `http/admin_auth_plug.ex` | Plug auth admin con JWT |
| `ElPaso.HTTP.AnthropicProxy` | `http/anthropic/proxy.ex` | Conversión formato Anthropic ↔ interno |
| `ElPaso.HTTP.WebSocketHandler` | `http/websocket/handler.ex` | WebSocket handler (Cowboy) |
| `ElPaso.HTTP.Dashboard` | `http/dashboard.ex` | Dashboard HTML + API JSON |
| `ElPaso.Engine.Registry` | `engine/registry.ex` | Registro engines en ETS |
| `ElPaso.Engine.ChatTemplate` | `engine/chat_template.ex` | Formateo de mensajes |

---

## 5. Módulos Stubs / No Implementados

### 5.1 Stubs Críticos (deberían ser funcionales)

| Módulo | Archivo | Problema |
|--------|---------|----------|
| `ElPaso.Context.Manager.reload_session()` | `context/manager.ex` | Siempre devuelve `{:error, :not_found}` — no usa Storage.get_session() |
| `ElPaso.Engine.Dispatcher.determine_model()` | `engine/dispatcher.ex` | Siempre devuelve `"default_model"` |
| `ElPaso.Engine.Ollama.infer()` | `engine/ollama.ex` | Devuelve `"response from ollama"` — stub |
| `ElPaso.Context.EmbeddingClient` | `context/embedding_client.ex` | `ping()`, `embed()` → `{:error, :not_configured}` |
| `ElPaso.Context.SummarizationWorker` | `context/summarization_worker.ex` | `generate_summary()` → `"Resumen generado"` |
| `ElPaso.HTTP.InternalClient.chat()` | `http/internal_client.ex` | `chat()` → `"response"` |
| `ElPaso.Domain.RouterStats.aggregate()` | `domain/router_stats.ex` | Devuelve struct vacío |

### 5.2 Stubs de Supervisores Vacíos

| Módulo | Archivo | Problema |
|--------|---------|----------|
| `ElPaso.Context.SessionSupervisor` | `context/session_supervisor.ex` | `children = []` |
| `ElPaso.Context.SummarizationSupervisor` | `context/summarization_supervisor.ex` | `children = []` |
| `ElPaso.Event.Supervisor` | `event/supervisor.ex` | `children = []` |

### 5.3 Mix Tasks Stub

| Tarea | Archivo | Problema |
|-------|---------|----------|
| `mix elpaso model add` | `model/add.ex` | Solo imprime "✅ Model added" |
| `mix elpaso model list` | `model/list.ex` | Muestra datos fake hardcoded |
| `mix elpaso model remove` | `model/remove.ex` | Solo imprime "✅ Removed" |
| `mix elpaso model start` | `model/start.ex` | Solo imprime "✅ Started" |
| `mix elpaso model stop` | `model/stop.ex` | Solo imprime "✅ Stopped" |
| `mix elpaso engine add` | `engine/add.ex` | Solo imprime "✅ Engine added" |
| `mix elpaso engine list` | `engine/list.ex` | Muestra datos fake hardcoded |
| `mix elpaso engine remove` | `engine/remove.ex` | Solo imprime "✅ Removed" |
| `mix elpaso engine test` | `engine/test.ex` | Solo imprime "✅ Tested" |

### 5.4 CLI Handlers Stub

| Handler | Archivo | Problema |
|---------|---------|----------|
| `handle_model(["list"])` | `cli.ex` | Tabla vacía hardcoded |
| `handle_model(["add"])` | `cli.ex` | Solo imprime help |
| `handle_model(["delete", "update", "show"])` | `cli.ex` | Sin conexión a DB |
| `handle_engine(["list"])` | `cli.ex` | Engines fake hardcoded |
| `handle_engine(["add", "delete", "update", "show"])` | `cli.ex` | Sin conexión a DB |
| `handle_personality` | `cli.ex` | Todos stubs |
| `handle_config(["show", "reload"])` | `cli.ex` | Solo imprime mensaje |
| `handle_server` | `cli.ex` | Solo notas informativas |

---

## 6. Análisis de Lagunas Críticas

### 6.1 Lagunas de Concepto

#### 🔴 Perfiles (Schema existe, CLI no)

El concepto de "perfil" (conjunto de modelo + engine + personalidad) **tiene schema Ecto y tabla en DB**, pero:
- No hay CLI command `profile add/list/delete/show`
- No hay integración entre router y perfiles
- No hay lógica de selección de perfil por request

**Impacto**: Sin CLI de perfiles, el usuario no puede crear/ver configuraciones completas.

#### 🔴 Personalidades (Schema existe, CLI stub)

Las personalidades tienen schema Ecto y tabla en DB, pero:
- `handle_personality()` en CLI es stub
- No hay sistema de system prompts asociado a perfiles en la práctica
- El `PrefixManager` tiene un system prompt hardcoded

**Impacto**: Sin CLI funcional de personalidades, no hay forma de cambiar el comportamiento del modelo.

### 6.2 Lagunas de Persistencia

#### ✅ Migraciones — YA HECHO

Existen 2 archivos de migración que crean todas las tablas necesarias:
- `priv/repo/migrations/20240101000000_create_initial_tables.exs` — tablas principales + pgvector
- `priv/repo/migrations/20240421_initial_setup.exs` — tablas adicionales (auto_tune_runs, api_usage, model_pricing, sessions_shared)

#### ✅ Storage → Repo — YA HECHO

`Context.Storage` usa Ecto queries reales con Repo. No son stubs.

#### 🔴 DB Auto-create

No hay lógica de auto-inicialización de DB:
- No existe `ElPaso.DBInitializer`
- No hay comando CLI que cree la DB si no existe
- No hay soporte para Docker mode (levantar PostgreSQL en contenedor)

### 6.3 Lagunas del Pipeline HTTP

#### 🔴 No hay endpoint OpenAI compatible

El requisito dice que ElPaso debe ser un proxy para apps como opencode, openclaw, vscode, zed. Estas apps usan la API de OpenAI (`/v1/chat/completions`). Pero:
- No existe el endpoint `/v1/chat/completions` en `HTTP.Server`
- Solo existen `/v1/messages` (Anthropic) y `/infer` (genérico)

#### 🔴 Pipeline de inferencia no conectado

El flujo debería ser:
```
Request → RequestParser → Router → Engine Dispatcher → Engine → Response
```

Pero actualmente:
```
Request → AnthropicProxy.from_anthropic() → run_anthropic_pipeline() → fake response
```

El router NUNCA se invoca desde el HTTP server. El dispatcher NUNCA se invoca. Los engines NUNCA se invocan.

### 6.4 Lagunas de CLI → DB

#### 🔴 CLI no conecta a Base de Datos

Todos los comandos CLI son simulaciones. No hay:
- Conexión a Repo desde las mix tasks (las tasks no inician la app)
- Uso de Ecto changesets para CRUD
- Validación de datos antes de insertar
- Manejo de errores de DB

### 6.5 Lagunas de Zaguan

#### 🟡 Zaguan referenced pero no integrado

Se encuentra una referencia real a Zaguan en `ElPaso.CLI.Commands.RouterStats`:
```elixir
alias Zaguan.Drawer.Components.{Header, Table}
```

Esto significa que:
1. Zaguan está como dependencia (`{:zaguan, path: "../zaguan"}`)
2. Al menos un módulo CLI usa componentes de Zaguan para renderizado
3. Pero el resto del CLI no usa Zaguan

### 6.6 Lagunas de Batamanta

#### 🟡 Batamanta como dependencia `runtime: false`

Batamanta se usa solo para compilar el escript `elpaso`. No hay:
- Lógica de auto-inicialización de DB
- Soporte para contenedor Docker embebido
- Lógica de "primera ejecución" que cree la DB

---

## 7. Problemas de Diseño y Calidad

### 7.1 Inconsistencias de Nomenclatura

| Problema | Ejemplo |
|----------|---------|
| `model` vs `engine` confuso | En CLI `model add --engine <engine>` pero en mix task `engine add --type <type>` |
| `personality` vs `profile` | Personality es un concepto, profile es el conjunto — pero no hay relación clara en la CLI |
| `elpaso.conf` formato INI | Se usa formato INI pero no hay parser INI/TOML genérico (solo en Config.Loader) |

### 7.2 Estructura de Directorios

```
lib/
├── el_paso/           # Módulos principales
│   ├── cli/           # CLI commands
│   │   └── commands/  # Subcomandos CLI
│   ├── config/        # Config modules
│   ├── context/       # Context management
│   │   ├── schemas/   # Ecto schemas
│   │   └── ...
│   ├── domain/        # Domain logic
│   │   ├── router/    # Router submodules
│   │   └── types/     # Type structs
│   ├── engine/        # Engine modules
│   │   ├── plugin/    # Engine plugins
│   │   └── ...
│   ├── http/          # HTTP modules
│   │   ├── anthropic/ # Anthropic proxy
│   │   └── websocket/ # WebSocket handler
│   ├── models/        # Model/Engine schemas (Ecto)
│   ├── security/      # Security modules
│   ├── storage/       # Storage adapters
│   ├── telemetry/     # Telemetry modules
│   └── downloader/    # Model downloader
├── el_paso.ex         # Main module
└── mix/tasks/         # Mix tasks
    └── elpaso/        # Subtasks
```

**Problemas**:
- ⚠️ `models/model.ex` y `models/engine.ex` ahora son Ecto schemas ✅ (ya no son defstructs)
- ⚠️ No hay módulo `Profile` o `Personality` en CLI (aunque schemas existen)
- ⚠️ Doble capa de schemas: `context/schemas/` (Session, Message, etc.) y `models/` (Model, Engine, etc.) — conviven sin conflicto pero es confuso

### 7.3 Anti-patrones Identificados

1. **Stub masivo**: ~40% de los módulos son stubs que devuelven datos fake
2. **Hardcoded data**: Mix tasks muestran datos hardcoded en vez de leer de DB
3. **Doble capa de schemas**: `context/schemas/` y `models/` — ambos con Ecto, pero separados
4. **No validation**: Los schemas Ecto tienen changesets pero nunca se usan desde CLI
5. **Magic strings**: `"auto"`, `"default_model"`, `"session_"` como valores por defecto
6. **Config hardcoded**: Modelos "fast" y "heavy" hardcodeados en `runtime.exs`

### 7.4 OTP Issues

1. **Supervisores vacíos**: `SessionSupervisor`, `SummarizationSupervisor`, `Event.Supervisor` no supervisan nada
2. **Falta ETS cleanup**: Las tablas ETS (`:session_states`, `:prefix_blocks`, `:rate_limiter`, `:engine_registry`) no tienen cleanup en `terminate/2`

---

## 8. Integración con Zaguan

### 8.1 Lo que se sabe de Zaguan

- Zaguan está en `~/proyectos/zaguan`
- Es una dependencia local: `{:zaguan, path: "../zaguan"}`
- Se usa al menos un componente: `Zaguan.Drawer.Components.{Header, Table}`
- El wizard de config referencia `Zaguan.UI.Select` y `Zaguan.UI.Confirm` (stub)

### 8.2 Qué debería reutilizarse de Zaguan

| Funcionalidad | Estado actual | Debería usar Zaguan |
|---------------|---------------|---------------------|
| Tablas de datos | IO.puts manual | `Zaguan.Drawer.Components.Table` ✅ (ya se usa en RouterStats) |
| Headers de output | IO.puts manual | `Zaguan.Drawer.Components.Header` ✅ (ya se usa en RouterStats) |
| Selectores interactivos | No implementado | `Zaguan.UI.Select` |
| Confirmaciones | IO.puts + :ok | `Zaguan.UI.Confirm` |
| Input de texto | No implementado | `Zaguan.UI.Input` |
| Progress bars | No implementado | `Zaguan.UI.Progress` |
| Colores/formato | IO.puts plain | `Zaguan.Drawer.Components` |

### 8.3 Recomendación

Todo el output del CLI debería pasar por componentes de Zaguan para:
1. Consistencia visual
2. Reutilización de código
3. Soporte para diferentes terminales/entornos
4. Accesibilidad y theming

---

## 9. Integración con Batamanta

### 9.1 Configuración Actual

```elixir
defp batamanta do
  [
    format: :escript,
    execution_mode: :cli,
    compression: 1,
    binary_name: @binary_name
  ]
end
```

Batamanta se usa para compilar el escript `elpaso`. La alias `gen` hace:
```
compile → batamanta → deploy → tools_version
```

### 9.2 Lo que falta

El requisito dice que el CLI debe ser autónomo y capaz de crear su propia DB. Esto implica:

1. **Auto-init de DB**: Al primer arranque, si la DB no existe, crearla
2. **Docker mode**: Si se configura `db_type = "docker"`, levantar un contenedor PostgreSQL
3. **Local mode**: Si se configura `db_type = "local"`, asumir que PostgreSQL está instalado y conectado
4. **Migraciones automáticas**: Ejecutar `ecto.migrate` automáticamente en primer arranque

### 9.3 Recomendación

Batamanta debería empaquetar:
- El escript de ElPaso
- Un script de inicialización de DB (shell script o Elixir)
- La configuración por defecto de `elpaso.conf`
- Las migraciones de Ecto

---

## 10. Plan de Acción Priorizado

### Fase 1: Fundamentos (CRÍTICO)

Estas son las bases sin las cuales nada funciona:

#### 1.1 Base de Datos
- [x] ~~Crear `priv/repo/migrations/` directory~~ — HECHO (2 migraciones existentes)
- [x] ~~Migration 001: crear tablas~~ — HECHO (`20240101000000` y `20240421_initial_setup`)
- [x] ~~Configurar `ElPaso.Repo` en el supervision tree~~ — HECHO (`application.ex`)
- [x] ~~Conectar `Context.Storage` a Repo~~ — HECHO (queries Ecto reales)
- [ ] Migraciones para pgvector (columnas de embedding) — ✅ Ya incluido en migration principal
- [ ] Seed data: engines, models, personalities, profiles por defecto

#### 1.2 Configuración
- [x] ~~Implementar parser de `elpaso.conf`~~ — HECHO (parser INI en Config.Loader)
- [x] ~~`Config.Loader` debe leer de archivo + env vars~~ — HECHO (prioridad correcta)
- [ ] Eliminar modelos hardcodeados de `runtime.exs`
- [ ] `Config.get_affinity()` y `update_affinity()` deben leer/escribir en DB

#### 1.3 Schemas de Modelos
- [x] ~~Reemplazar `ElPaso.Models.Model` (defstruct) con Ecto schema~~ — HECHO
- [x] ~~Crear `ElPaso.Models.Engine` Ecto schema~~ — HECHO
- [x] ~~Crear `ElPaso.Models.Personality` Ecto schema~~ — HECHO
- [x] ~~Crear `ElPaso.Models.Profile` Ecto schema~~ — HECHO

### Fase 2: CLI Funcional

#### 2.1 CRUD de Modelos
- [ ] `mix elpaso model add` → insert en DB vía Repo
- [ ] `mix elpaso model list` → query desde DB con tablas Zaguan
- [ ] `mix elpaso model remove` → delete desde DB
- [ ] `mix elpaso model show` → get desde DB
- [ ] `mix elpaso model update` → update en DB

#### 2.2 CRUD de Engines
- [ ] `mix elpaso engine add` → insert en DB
- [ ] `mix elpaso engine list` → query desde DB con tablas Zaguan
- [ ] `mix elpaso engine remove` → delete desde DB
- [ ] `mix elpaso engine test` → health_check real al engine

#### 2.3 CRUD de Personalidades
- [ ] `mix elpaso personality add` → insert en DB con system_prompt
- [ ] `mix elpaso personality list` → query desde DB
- [ ] `mix elpaso personality delete` → delete desde DB
- [ ] `mix elpaso personality show` → get desde DB

#### 2.4 CRUD de Perfiles (NUEVO)
- [ ] `mix elpaso profile add --name <n> --model <m> --engine <e> --personality <p>`
- [ ] `mix elpaso profile list`
- [ ] `mix elpaso profile delete`
- [ ] `mix elpaso profile show`

#### 2.5 Server Command
- [ ] `elpaso server start` → arranca la aplicación Elixir (`mix run --no-halt`)
- [ ] `elpaso server stop` → envía SIGTERM al PID guardado
- [ ] `elpaso server status` → verifica si el proceso está corriendo
- [ ] `elpaso server log` → tail de logs

### Fase 3: Pipeline de Inferencia

#### 3.1 HTTP Server
- [ ] Implementar endpoint `/v1/chat/completions` (OpenAI compatible)
- [ ] Conectar RequestParser → Router → Engine Dispatcher
- [ ] `run_anthropic_pipeline()` debe invocar el pipeline real
- [ ] `run_anthropic_stream()` debe invocar streaming real

#### 3.2 Engine Adapters
- [ ] Implementar adapter OpenAI (usando Finch)
- [ ] Implementar adapter Anthropic (usando Finch)
- [ ] Mejorar adapter Ollama (usando Finch, no stub)
- [ ] Implementar adapter llama.cpp (HTTP server local)

#### 3.3 Router Real
- [ ] Conectar `ModelManager` a DB para obtener estados reales de modelos — ✅ Ya carga de DB
- [ ] `ModelState` debe tener todos los campos necesarios — ✅ Ya tiene routing_config
- [ ] `Storage.save_routing_decision()` debe persistir en DB — ✅ Ya es Ecto query real
- [ ] `Storage.update_routing_outcome()` debe actualizar en DB — ✅ Ya es Ecto query real

### Fase 4: Contexto y Sesiones

#### 4.1 Storage Real
- [x] ~~`Storage.create_session()` → Ecto insert~~ — HECHO
- [x] ~~`Storage.get_session()` → Ecto query~~ — HECHO
- [x] ~~`Storage.get_all_messages()` → Ecto query con orden~~ — HECHO
- [x] ~~`Storage.get_latest_summary()` → Ecto query~~ — HECHO
- [ ] `Context.Manager.reload_session()` debe usar Storage.get_session()

#### 4.2 Embeddings
- [ ] Implementar `EmbeddingClient` real (usar modelo local o API)
- [ ] Crear índice IVFFlat en pgvector — ✅ Ya incluido en migration
- [ ] `rebuild_embeddings` debe generar embeddings para mensajes sin embedding

#### 4.3 Summarization
- [ ] `SummarizationWorker` debe invocar un modelo para resumir
- [ ] `SummarizationSupervisor` debe supervisar workers
- [ ] Guardar resúmenes en DB — ✅ Schema existe

### Fase 5: Integración Zaguan

#### 5.1 UI Components
- [ ] Reemplazar todo IO.puts con componentes Zaguan
- [ ] Usar `Zaguan.Drawer.Components.Table` para todas las tablas
- [ ] Usar `Zaguan.Drawer.Components.Header` para headers
- [ ] Implementar `Zaguan.UI.Select` para selección interactiva
- [ ] Implementar `Zaguan.UI.Confirm` para confirmaciones
- [ ] Implementar `Zaguan.UI.Input` para entrada de texto

#### 5.2 Reutilización
- [ ] Identificar todas las funcionalidades de Zaguan que ElPaso necesita
- [ ] Mover lógica compartida a Zaguan si aplica
- [ ] Documentar dependencias de Zaguan en README

### Fase 6: Batamanta y Autonomía

#### 6.1 Auto-init de DB
- [ ] Crear módulo `ElPaso.DBInitializer` que:
  - Verifica conexión a DB
  - Si no existe, crea la DB (postgres mode)
  - Ejecuta migraciones
  - Crea seed data si es necesario

#### 6.2 Docker Mode
- [ ] Si `db_type = "docker"` en config:
  - Levantar contenedor PostgreSQL con Docker
  - Esperar a que esté ready
  - Conectar y migrar

#### 6.3 Empaquetado
- [ ] Batamanta debe incluir script de init de DB
- [ ] Batamanta debe incluir migraciones
- [ ] Batamanta debe incluir config por defecto

### Fase 7: Calidad y OTP

#### 7.1 Supervision Tree
- [ ] Rellenar `SessionSupervisor` con hijos reales (Context.Manager)
- [ ] Rellenar `SummarizationSupervisor` con hijos reales (SummarizationWorker)
- [ ] Rellenar `Event.Supervisor` con handlers reales
- [ ] Añadir `terminate/2` para cleanup de ETS

#### 7.2 Testing
- [ ] Tests unitarios para módulos con lógica real (router, auto-tuner, JWT, etc.)
- [ ] Tests de integración para CLI commands
- [ ] Tests del pipeline HTTP completo

#### 7.3 Documentación
- [ ] README actualizado con arquitectura real
- [ ] Guía de configuración
- [ ] Guía de migraciones DB
- [ ] API reference completa

---

## Resumen de Prioridades

| Prioridad | Fase | Impacto |
|-----------|------|---------|
| 🔴 P0 | 2.1-2.4 - CLI CRUD | Sin CLI funcional, no se puede administrar el sistema |
| 🔴 P0 | 3.1 - Pipeline HTTP | Sin pipeline real, el proxy no sirve para nada |
| 🔴 P0 | 6.1 - DB Auto-init | Sin auto-init, no hay arranque autónomo |
| 🟡 P1 | 2.5 - Server Command | CLI no puede gestionar el servidor |
| 🟡 P1 | 3.2-3.3 - Engine Adapters | Router no tiene engines reales para enrutar |
| 🟡 P1 | 4.2-4.3 - Embeddings/Summarization | Contexto semántico no funciona |
| 🟢 P2 | 5.1-5.2 - Zaguan | Calidad y consistencia CLI |
| 🟢 P2 | 6.2-6.3 - Batamanta | Empaquetado autónomo |
| 🟢 P3 | 7.1-7.3 - Calidad | Robustez y mantenibilidad |

---

## Notas Finales

### Lo que está bien hecho
1. **Arquitectura OTP**: La estructura de supervision tree es correcta
2. **Router heurístico**: El motor de routing con feature extraction y scoring es sofisticado y funcional
3. **AutoTuner**: El sistema de auto-tuning periódico con revert es bien diseñado
4. **Plugin system**: El loader de plugins dinámicos es una buena abstracción
5. **Security**: JWT, auth, rate limiter están implementados correctamente
6. **ModelDownloader**: Descarga desde HF con streaming y checksum es robusta
7. **WebSocket handler**: Implementación completa del protocolo Cowboy
8. **Base de datos**: Migraciones, schemas Ecto y Storage conectados a Repo — todo funcional

### Lo que necesita trabajo urgente
1. **Conectar CLI a Base de Datos** — los comandos actuales son simulaciones
2. **Implementar el pipeline de inferencia HTTP** — las respuestas fake no sirven
3. **Endpoint `/v1/chat/completions`** — apps como opencode necesitan API OpenAI compatible
4. **Implementar adapters de engines** (OpenAI, Anthropic) — sin engines reales, el router no sirve

### Filosofía de implementación recomendada
> "Primero que funcione, luego que sea bonito."
> 
> 1. Primero conectar CLI a DB y hacer que los comandos persistan datos reales
> 2. Luego implementar el pipeline de inferencia completo
> 3. Luego añadir perfiles y detección de perfiles
> 4. Luego integrar Zaguan para UI consistente
> 5. Finalmente Batamanta y empaquetado autónomo

---

## Proximidad a Objetivos por Capa

| Capa | Progreso | Detalle |
|------|----------|---------|
| Configuración | 🟢 90% | Parser INI + env vars ✅, falta affinity DB-backed |
| Base de Datos | 🟢 85% | Migraciones + schemas + Storage ✅, falta auto-init |
| OTP / Supervisión | 🟡 60% | Repo + Registry + AutoTuner ✅, supervisors vacíos |
| Router / Domain | 🟢 90% | Heurística completa ✅, falta engine real |
| Contexto / Sesiones | 🟢 80% | Manager + Builder + Storage ✅, reload_session stub |
| HTTP / Proxy | 🔴 30% | Endpoints ✅, pipeline fake ❌ |
| Engines | 🔴 20% | Registry + ChatTemplate ✅, adapters fake ❌ |
| CLI | 🔴 10% | Help text ✅, CRUD fake ❌ |
| Seguridad | 🟢 95% | JWT + Auth + RateLimiter ✅ |
| Telemetría / Costos | 🟢 85% | Store + CostManager ✅, pricing DB-backed ❌ |
| Cluster | 🟡 60% | NodeRegistry ✅, model states fake ❌ |
| Zaguan | 🟡 20% | Table/Header usados ✅, resto por integrar ❌ |

---

*Fin del análisis. Para el estado actualizado y tareas pendientes, ver `IMPLEMENTATION_TRACKER.md`.*
