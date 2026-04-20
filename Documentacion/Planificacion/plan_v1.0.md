# Plan V1.0 — Sistema Funcional Local

> **Spec**: [v1.0.md](../v1.0.md) | **Prerequisito**: V0 completado

## Objetivo
Sistema completamente funcional para uso local: request HTTP → routing → context → inferencia → respuesta.

## Modelos asignados
| Alias doc | Modelo local | opencode arg              |
|-----------|-------------|---------------------------|
| devstral  | thinker     | llama-cpp-local/thinker   |
| coder     | coder       | llama-cpp-local/coder     |
| Thinker   | r1          | llama-cpp-local/logic     |

---

## BLOQUE 1 — Arquitectura OTP + Config System (thinker)

**Modelo**: `thinker` | **Estimación**: ~45 min

**Tareas**:
1. `ElPaso.Application.start/2` con árbol de supervisión completo: Repo, ModelSupervisor (→ ModelRegistry + ModelPool DynamicSupervisor), Context.Manager GenServer, HTTP.Endpoint Plug.Cowboy, Telemetry supervisor
2. `ElPaso.Config.Schema` — definición NimbleOptions del schema completo (meta, system, session_defaults, engines, models, routing, canonical_prefix, summarization)
3. `ElPaso.Config.Loader` — lectura `~/.config/elpaso/elpaso.conf`, JSON parse, validación con Schema, watch via inotify/polling
4. `ElPaso.Config.Validator` — validaciones cruzadas: puertos únicos, paths existen, engine_args vs inference_defaults separación
5. `ElPaso.Config.Merger` — fusión engine.base_args + model.engine_args con reglas: model gana, null elimina, bool→flag
6. `ElPaso.Config.ConditionEvaluator` — DSL de operadores (lt/lte/gt/gte/eq/neq/in/not_in), soporte all_of/any_of
7. Configs Elixir: config.exs, dev.exs, test.exs, runtime.exs con Ecto y Endpoint

**Ref**: Secciones "BLOQUE 4: Config" y "ModelManager: árbol de supervisión" de v1.0.md

---

## BLOQUE 2 — Schemas Ecto + Storage + TokenCounter (coder)

**Modelo**: `coder` | **Estimación**: ~30 min

**Tareas**:
1. Migraciones Ecto: 001_sessions (UUID, context_mode, metadata JSONB), 002_messages (embedding vector(768), indices), 003_conversation_summaries, 004_routing_decisions (feature_vector JSONB, scores JSONB)
2. Schemas Ecto: Session, Message (con Pgvector.Ecto.Vector), ConversationSummary, RoutingDecision — cada uno con changeset/2
3. `ElPaso.Context.Storage` — toda la interfaz: create_session/1, touch_session/1, delete_session/1, save_message/4, get_window/2, archive_messages_before/2, search_semantic/3, get_latest_summary/1, save_summary/3, save_routing_decision/1, update_routing_outcome/3
4. `ElPaso.Context.TokenCounter` — estimate/1 (chars/3 para español), count/2 con fallback

**Ref**: "Context.Storage" y "Schema PostgreSQL" de v1.0.md

---

## BLOQUE 3 — Portable Session Context (coder)

**Modelo**: `coder` | **Estimación**: ~40 min

**Tareas**:
1. `ElPaso.Context.PrefixManager` (GenServer): build/2, get/1, invalidate/1, hash/1; PrefixBlock con SHA256; ETS storage
2. `ElPaso.Context.Builder` (funcional puro): build/3 ensamblado 5 capas (canónico→resumen→semántica→ventana→actual), estimate_budget/2, BuiltPrompt struct, adaptación context_spec, modo transparente/declarativo
3. `ElPaso.Context.Manager` (GenServer): get_or_create_session/1, append_turn/4, get_context_layers/2, expire_session/1, reload_session/1; SessionState en ETS; ventana deslizante con promoción a Capa 2; trigger eager 80%
4. `ElPaso.Context.SummarizationWorker`: job async, prompt configurable, usa modelo ligero, telemetría de compresión

**Ref**: "PILAR 1" y "PILAR 2" de v1.0.md

---

## BLOQUE 4 — Engine Adapters + Dispatcher (coder)

**Modelo**: `coder` | **Estimación**: ~35 min

**Tareas**:
1. `ElPaso.Engine.Base` behaviour: callbacks infer/3, stream/4, prepare_prefix/2, health_check/1, format_messages/2
2. `ElPaso.Engine.LlamaServer` — HTTP via Finch, streaming SSE, health check /health
3. `ElPaso.Engine.OpenAI` — API OpenAI estándar
4. `ElPaso.Engine.Anthropic` — con cache_control para system prompt
5. `ElPaso.Engine.Ollama` — wrapper sobre OpenAI con base_url localhost:11434
6. `ElPaso.Engine.Dispatcher` — punto de entrada único, resolve engine, delega
7. `ElPaso.Engine.ChatTemplate` — format/3 para gemma/chatml/llama3/mistral/openai/anthropic
8. `ElPaso.Domain.OutputCache` — GenServer, ETS, LRU+TTL

**Ref**: "Integración con backends" y "Módulos adicionales" de v1.0.md

---

## BLOQUE 5 — ModelManager + ModelWorker (thinker)

**Modelo**: `thinker` | **Estimación**: ~40 min

**Tareas**:
1. `ElPaso.Domain.ModelSupervisor` (Supervisor :one_for_one)
2. `ElPaso.Domain.ModelRegistry` (Registry por model_id)
3. `ElPaso.Domain.ModelPool` (DynamicSupervisor)
4. `ElPaso.Domain.ModelWorker` (GenServer, uno por modelo): Zaguan.Engine.execute/2, engine_policy/1 con Policies, health check 30s (RAM /proc, VRAM nvidia-smi), parada por inactividad, ModelState completo
5. `ElPaso.Domain.ModelManager` (fachada): ensure_hot/2, stop/1, state/1, all_states/0, record_call_result/3, autostart

**Ref**: "ModelManager: ciclo de vida" de v1.0.md

---

## BLOQUE 6 — Heuristic Routing Engine (r1)

**Modelo**: `r1` | **Estimación**: ~35 min

**Tareas**:
1. `Router.FeatureExtractor`: FeatureVector 7 campos, task_type por heurísticas léxicas (keywords+regex), complexity_score fórmula lineal ponderada, detección idioma/structured/continuación
2. `Router.ConditionEvaluator`: use_when/prefer_when/avoid_when, operadores DSL, all_of/any_of
3. `Router.Scorer`: fit_score (task_affinity × complexity_ceiling), capability_multiplier, cold_start_penalty, queue_penalty, error_penalty
4. `ElPaso.Domain.Router`: route/3 pipeline 5 fases, record_outcome/3 feedback loop, recent_decisions/1, stats/0, fallback, RoutingDecision registro

**Ref**: "PILAR 3: Heuristic Routing Engine" de v1.0.md

---

## BLOQUE 7 — HTTP Layer + Seguridad (coder)

**Modelo**: `coder` | **Estimación**: ~30 min

**Tareas**:
1. `ElPaso.HTTP.Router` (Plug.Router): POST /v1/chat/completions, POST /v1/completions, GET /v1/models, GET /health, GET /status
2. Streaming SSE: proxy directo, formato OpenAI, primer chunk con elpaso metadata
3. Formato respuesta con extensión elpaso (session_id, routing_decision, context_layers_used)
4. Errores estructurados: elpaso_503/504/422/500, model_error 502
5. `ElPaso.Security`: API key local, rate limiting token bucket ETS, sanitización input, CORS
6. Pipeline completo: request → router → context → engine → response

**Ref**: "ElPaso.HTTP" y "Seguridad básica V1.0" de v1.0.md

---

## BLOQUE 8 — Config Wizard + CLI + Telemetría (coder)

**Modelo**: `coder` | **Estimación**: ~25 min

**Tareas**:
1. `ElPaso.Config.Wizard` con Zaguan.UI.Components: 8 pasos (bienvenida→sistema→db→modelo→más modelos→system prompt→revisión→test arranque), 3 modos (crear/editar/add-model), EnvironmentDetector para GPUs/RAM/binarios
2. Mix tasks: mix elpaso.setup, mix elpaso.models, mix elpaso.config.reload, mix elpaso.config.validate
3. Telemetría: attach handlers para TODOS los eventos (prefix:hit/miss, context:built/window_trimmed/compressed, router:decision/fallback, model:cold_start/health_check, inference:complete/error)
4. Test integración end-to-end

**Ref**: "Config.Wizard" y "Telemetría" de v1.0.md

---

## Resumen de ejecución

| Bloque | Modelo  | Descripción                      | Dep           |
|--------|---------|----------------------------------|---------------|
| 1      | thinker | Arquitectura OTP + Config        | V0            |
| 2      | coder   | Schemas + Storage                | B1            |
| 3      | coder   | Portable Session Context         | B1,2          |
| 4      | coder   | Engine adapters + Dispatcher     | B1            |
| 5      | thinker | ModelManager + ModelWorker        | B1,4          |
| 6      | r1      | Router heurístico                | B1,2,5        |
| 7      | coder   | HTTP + Seguridad                 | B3-6          |
| 8      | coder   | Wizard + CLI + Telemetría        | Todos         |

**Orden de modelos**: thinker → coder → coder → coder → thinker → r1 → coder → coder
**Cambios de modelo**: 4 (thinker→coder, coder→thinker, thinker→r1, r1→coder)
