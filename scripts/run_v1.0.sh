#!/usr/bin/env bash
# =============================================================================
# run_v1.0.sh — Automatización ElPaso V1.0: Sistema Funcional Local
# =============================================================================
source "$(dirname "$0")/common.sh"

version_header "V1.0" "Sistema Funcional Local"

# ---------------------------------------------------------------------------
# BLOQUE 1: Arquitectura OTP + Config System (thinker)
# ---------------------------------------------------------------------------
PROMPT_B1=$(cat <<'PROMPT'
Eres un arquitecto Elixir/OTP experto. Implementa el sistema de configuración y árbol OTP de ElPaso.

Lee la documentación completa en Documentacion/v1.0.md y Documentacion/v0.md para el contexto del proyecto. Zaguan está en ~/proyectos/zaguan — consulta su código fuente si necesitas entender su API (Engine, Drawer, UI).

IMPLEMENTA ESTOS MÓDULOS:

1. ElPaso.Application.start/2 — Árbol de supervisión:
   - ElPaso.Repo
   - {Finch, name: ElPasoFinch}
   - ElPaso.Domain.ModelSupervisor (Supervisor :one_for_one) que supervisa:
     → ElPaso.Domain.ModelRegistry (Registry)
     → ElPaso.Domain.ModelPool (DynamicSupervisor)
     → ElPaso.Context.Manager (GenServer)
     → ElPaso.Domain.OutputCache (GenServer)
     → {Plug.Cowboy, scheme: :http, plug: ElPaso.HTTP.Router, options: [port: config_port]}

2. ElPaso.Config.Schema — Definición NimbleOptions del schema completo:
   Secciones: meta (version, created_at), system (http_port, log_level, telemetry_enabled, db_url, port_range), session_defaults (latency_tolerance_ms, context_mode, semantic_retrieval, window_size, summary_strategy, summary_trigger_pct, summarize_with_model), engines (map de engine configs con type, binary, base_args, health_check_*, startup/shutdown_timeout_ms), models (lista con id, label, enabled, engine, source, engine_args, inference_defaults, context_spec, routing con priority/cold_start_estimate_ms/task_affinity/conditions/complexity_ceiling), routing (complexity_weights, cold_start_penalty_factor, max_consecutive_errors, fallback_timeout_ms, score_tie_threshold), canonical_prefix (system_prompt_file, reference_documents, version), summarization (prompt_file)

3. ElPaso.Config.Loader — Lee ~/.config/elpaso/elpaso.conf (JSON), parsea con Jason, valida con Schema, almacena en ETS para acceso rápido. Funciones: load/1, reload/0, get/0, get_model/1, watch/1 (inotify o polling).

4. ElPaso.Config.Validator — Validaciones cruzadas: puertos únicos entre modelos, paths de GGUF existen, engine_args no contiene inference params (warning), variables de entorno para API keys.

5. ElPaso.Config.Merger — merge_engine_args/2: fusiona base_args + model_args. Model gana en conflicto, null elimina, true→flag sin valor, false→omitir. Devuelve [String.t()].

6. ElPaso.Config.ConditionEvaluator — evaluate/2: evalúa conditions contra contexto del request. Operadores: lt, lte, gt, gte, eq, neq, in, not_in. Agrupadores: all_of (AND), any_of (OR). Campos: complexity_score, task_type, token_estimate, model_status, queue_depth, etc.

Asegúrate de que mix compile pasa sin errores.
PROMPT
)

if ! run_block "thinker" "Arquitectura OTP + Config System" "$PROMPT_B1"; then
    echo -e "${RED}✗  Error crítico en V1.0 Bloque 1. Deteniendo.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# BLOQUE 2: Schemas Ecto + Storage + TokenCounter (coder)
# ---------------------------------------------------------------------------
PROMPT_B2=$(cat <<'PROMPT'
Eres un desarrollador Elixir experto. Implementa la persistencia de ElPaso.

Lee Documentacion/v1.0.md sección "Context.Storage" y "Schema PostgreSQL".

IMPLEMENTA:

1. Migraciones Ecto en priv/repo/migrations/:
   - 20250101000001_create_sessions.exs: sessions (id UUID PK, created_at, last_active_at, context_mode TEXT default 'transparent', metadata JSONB, user_id TEXT nullable). Índice en last_active_at.
   - 20250101000002_create_messages.exs: messages (id BIGSERIAL, session_id UUID FK→sessions CASCADE, sequence_number INT, role TEXT CHECK in user/assistant/system, content TEXT, token_estimate INT default 0, model_id TEXT, created_at, archived_at nullable, embedding vector(768) nullable). Índices: session+seq, session+active WHERE archived_at IS NULL.
   - 20250101000003_create_conversation_summaries.exs: conversation_summaries (id BIGSERIAL, session_id FK, content TEXT, covers_until_message_id BIGINT FK→messages, token_estimate INT, generated_by_model TEXT, generated_at). Índice: session+generated_at DESC.
   - 20250101000004_create_routing_decisions.exs: routing_decisions (request_id TEXT PK, session_id UUID FK SET NULL, selected_model TEXT, runner_up TEXT, task_type TEXT, complexity_score FLOAT, token_estimate INT, feature_vector JSONB, scores JSONB, reason TEXT, outcome TEXT nullable, latency_ms INT nullable, decided_at). Índices: session+decided_at DESC, selected_model+task_type.

2. Schemas Ecto en lib/elpaso/context/schemas/: Session, Message (con Pgvector.Ecto.Vector para embedding), ConversationSummary, RoutingDecision. Cada uno con changeset/2.

3. ElPaso.Context.Storage — TODA la interfaz pública:
   create_session/1, touch_session/1, delete_session/1,
   save_message/4 (session_id, role, content, opts), get_window/2 (session_id, limit),
   archive_messages_before/2, search_semantic/3 (session_id, embedding, limit),
   get_latest_summary/1, save_summary/3,
   save_routing_decision/1, update_routing_outcome/3

4. ElPaso.Context.TokenCounter — estimate/1 (String.length(text) / 3 para español), count/2 con model_id (fallback a estimate).

Ejecuta mix compile para verificar.
PROMPT
)

if ! run_block "coder" "Schemas Ecto + Storage" "$PROMPT_B2"; then
    echo -e "${RED}✗  Error crítico en V1.0 Bloque 2. Deteniendo.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# BLOQUE 3: Portable Session Context (coder)
# ---------------------------------------------------------------------------
PROMPT_B3=$(cat <<'PROMPT'
Eres un desarrollador Elixir experto. Implementa el Portable Session Context de ElPaso.

Lee Documentacion/v1.0.md secciones "PILAR 1: Shared Prompt Prefix" y "PILAR 2: Portable Session Context".

IMPLEMENTA:

1. ElPaso.Context.PrefixManager (GenServer):
   - build/2: construye PrefixBlock desde config (system_prompt_file + reference_documents + separador). Serialización determinista. Hash SHA256.
   - get/1: lee de ETS por session_id
   - invalidate/1: elimina de ETS
   - hash/1: devuelve hash del bloque
   - Almacena en tabla ETS :prefix_blocks. Inmutable por sesión.

2. ElPaso.Context.Builder (módulo funcional puro):
   - build/3 (session_id, current_message, context_spec): ensambla prompt en 5 capas:
     1) Bloque Canónico (PrefixManager)
     2) Resumen incremental (Capa 2)
     3) Contexto semántico (Capa 3, vacío si no activa)
     4) Ventana deslizante (mensajes recientes)
     5) Mensaje actual
   - estimate_budget/2: calcula tokens por capa según context_spec
   - Retorna BuiltPrompt struct. Si window supera budget, reduce desde el más antiguo.
   - Soporte modo transparente (sin mención cambio) y declarativo (nota de cambio de modelo).

3. ElPaso.Context.Manager (GenServer):
   - get_or_create_session/1: busca en ETS o carga desde PostgreSQL o crea nueva
   - append_turn/4: registra turno (user+assistant), actualiza ventana ETS, persiste en PostgreSQL, evalúa trigger eager (80% budget → dispara SummarizationWorker)
   - get_context_layers/2: devuelve %{summary, window, semantic}
   - expire_session/1: limpia ETS, datos quedan en PostgreSQL
   - reload_session/1: recarga desde PostgreSQL
   - SessionState en tabla ETS :session_state

4. ElPaso.Context.SummarizationWorker:
   - trigger_async/4: Task.start fire-and-forget, genera resumen vía Engine.Dispatcher.infer con modelo ligero, guarda via Storage.save_summary, emite telemetría context:compressed

Ejecuta mix compile para verificar.
PROMPT
)

if ! run_block "coder" "Portable Session Context" "$PROMPT_B3"; then
    echo -e "${RED}✗  Error crítico en V1.0 Bloque 3. Deteniendo.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# BLOQUE 4: Engine Adapters + Dispatcher (coder)
# ---------------------------------------------------------------------------
PROMPT_B4=$(cat <<'PROMPT'
Eres un desarrollador Elixir experto. Implementa los engine adapters de ElPaso.

Lee Documentacion/v1.0.md secciones sobre engines y los módulos adicionales obligatorios.

IMPLEMENTA:

1. ElPaso.Engine.Base — behaviour con callbacks:
   @callback infer(prompt, params, config) :: {:ok, Response.t()} | {:error, reason}
   @callback stream(prompt, params, config, chunk_callback) :: :ok | {:error, reason}
   @callback prepare_prefix(prefix, config) :: term()
   @callback health_check(config) :: :ok | {:error, reason}
   @callback format_messages(messages, context_spec) :: term()

2. ElPaso.Engine.LlamaServer — @behaviour ElPaso.Engine.Base:
   - infer/3: POST /v1/chat/completions via Finch, parsea respuesta OpenAI
   - stream/4: POST con stream:true, parsea SSE (data: {...}\n\n), callback por chunk
   - health_check/1: GET /health con timeout
   - prepare_prefix/2: no-op (implícito en llama-server)

3. ElPaso.Engine.OpenAI — API OpenAI estándar con api_key desde env
4. ElPaso.Engine.Anthropic — con cache_control {"type":"ephemeral"} en system prompt
5. ElPaso.Engine.Ollama — wrapper sobre OpenAI con base_url localhost:11434/v1, api_key nil

6. ElPaso.Engine.Dispatcher:
   - infer/3: resolve engine module desde config, delega
   - stream/4: igual con streaming
   - resolve_engine/1: mapea "llama_server"→LlamaServer, etc.

7. ElPaso.Engine.ChatTemplate — format/3:
   - :gemma → <start_of_turn>user\n...<end_of_turn>
   - :chatml → <|im_start|>system\n...<|im_end|>
   - :llama3 → <|begin_of_text|><|start_header_id|>...
   - :mistral → [INST]...[/INST]
   - :openai/:anthropic → {:passthrough, messages}

8. ElPaso.Domain.OutputCache (GenServer): ETS tabla :output_cache, get/1 con TTL check, put/2, stats/0, cleanup periódico

Ejecuta mix compile para verificar.
PROMPT
)

if ! run_block "coder" "Engine Adapters + Dispatcher" "$PROMPT_B4"; then
    echo -e "${RED}✗  Error crítico en V1.0 Bloque 4. Deteniendo.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# BLOQUE 5: ModelManager + ModelWorker (thinker)
# ---------------------------------------------------------------------------
PROMPT_B5=$(cat <<'PROMPT'
Eres un arquitecto Elixir/OTP experto. Implementa el ModelManager de ElPaso.

Lee Documentacion/v1.0.md sección "ModelManager: ciclo de vida" y Documentacion/v0.md sobre Zaguan.Engine.
Zaguan está en ~/proyectos/zaguan — consulta lib/zaguan/engine.ex, lib/zaguan/engine/policies.ex y lib/zaguan/engine/monitor.ex para entender la API.

IMPLEMENTA:

1. ElPaso.Domain.ModelSupervisor (Supervisor, strategy: :one_for_one):
   children: [ModelRegistry, ModelPool]

2. ElPaso.Domain.ModelRegistry: Registry, keys: :unique, name: __MODULE__

3. ElPaso.Domain.ModelPool: DynamicSupervisor

4. ElPaso.Domain.ModelWorker (GenServer, uno por modelo):
   - engine_policy/1: construye Zaguan.Engine.Policies desde model_config.lifecycle (on_error :retry/:stop, max_retries, retry_delay 2000, timeout)
   - start_engine/2: usa Zaguan.Engine.execute/2 para arrancar Port del motor con args fusionados por Config.Merger
   - Health check cada 30s: GET /health del motor, RAM via /proc/{pid}/status, VRAM via nvidia-smi
   - Parada por inactividad: evalúa max_idle_minutes y keepalive_minutes cada 60s
   - ModelState completo: status (:hot/:warming/:cold/:error/:disabled), pid, port, queue_depth, avg_latency_ms (EMA alpha=0.1), p95_latency_ms (ventana 50 últimas), errores, ram_mb, vram_mb, started_at, last_call_at, node
   - Suscripción a Zaguan.Engine.subscribe() para eventos de fallos

5. ElPaso.Domain.ModelManager (módulo fachada):
   - ensure_hot/2: :hot→:ok, :cold→arrancar+esperar, :warming→esperar, :error→error
   - stop/1, state/1, all_states/0
   - record_call_result/3: actualiza avg_latency (EMA), p95 (ventana), consecutive_errors
   - Al arrancar app: autostart modelos con autostart:true en secuencia por priority

Ejecuta mix compile para verificar.
PROMPT
)

if ! run_block "thinker" "ModelManager + ModelWorker" "$PROMPT_B5"; then
    echo -e "${RED}✗  Error crítico en V1.0 Bloque 5. Deteniendo.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# BLOQUE 6: Heuristic Routing Engine (r1)
# ---------------------------------------------------------------------------
PROMPT_B6=$(cat <<'PROMPT'
Eres un experto en razonamiento lógico y algoritmos. Implementa el router heurístico de ElPaso.

Lee Documentacion/v1.0.md sección "PILAR 3: Heuristic Routing Engine" completa.

IMPLEMENTA:

1. ElPaso.Domain.Router.FeatureExtractor:
   - extract/1: recibe user_message, devuelve FeatureVector
   - task_type: clasificador por heurísticas léxicas (keywords+regex para los 7 tipos: code, reasoning, summarization, question_answer, creative, translation, unknown)
   - complexity_score: función lineal ponderada:
     0.30*normalize(token_estimate) + 0.25*task_type_weight + 0.20*sentence_depth + 0.15*vocabulary_density + 0.10*normalize(question_count)
   - Detección idioma (simple: presencia palabras españolas/inglesas)
   - has_structured_output_request: detecta peticiones JSON/tabla/código
   - is_continuation: basado en session_id existente

2. ElPaso.Domain.Router.Scorer:
   - fit_score: task_affinity[task_type] * (1.0 - max(0, complexity_score - complexity_ceiling) * 0.5)
   - capability_multiplier: structured_output_score * multilingual_score
   - cold_start_penalty: min(1.0, cold_start_ms / latency_tolerance_ms) * penalty_factor si :cold, 0.0 si no
   - queue_penalty: queue_depth * 0.05
   - error_penalty: consecutive_errors >= max → infinity, else consecutive_errors * 0.15
   - final_score = (base_score - penalties) * capability_multiplier

3. ElPaso.Domain.Router:
   - route/3 (request_id, session_id, user_message): pipeline 5 fases:
     F1: Feature extraction
     F2: System state check (ModelManager.all_states)
     F3: ConditionEvaluator + Scoring para cada modelo
     F4: Decisión (max score) + fallback si :cold timeout
     F5: Registro RoutingDecision en Storage
   - record_outcome/3: actualiza ModelManager.record_call_result, persiste outcome+latency en routing_decisions
   - recent_decisions/1, stats/0
   - Telemetría: router:decision, router:fallback

Ejecuta mix compile para verificar.
PROMPT
)

if ! run_block "r1" "Heuristic Routing Engine" "$PROMPT_B6"; then
    echo -e "${RED}✗  Error crítico en V1.0 Bloque 6. Deteniendo.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# BLOQUE 7: HTTP Layer + Seguridad (coder)
# ---------------------------------------------------------------------------
PROMPT_B7=$(cat <<'PROMPT'
Eres un desarrollador Elixir experto. Implementa la capa HTTP de ElPaso.

Lee Documentacion/v1.0.md secciones sobre "ElPaso.HTTP" y "Seguridad básica en V1.0".

IMPLEMENTA:

1. ElPaso.HTTP.Router (Plug.Router):
   - POST /v1/chat/completions: parsear body, validar, crear/obtener sesión, route, ensure_hot, build context, infer/stream, append_turn, record_outcome, responder
   - POST /v1/completions: redirige a chat internamente
   - GET /v1/models: lista modelos con estado y metadata elpaso
   - GET /health: 200 siempre
   - GET /status: versión, uptime, modelos, sesiones activas, router stats

2. Streaming SSE: cuando stream:true, usar Engine.Dispatcher.stream con callback que envía chunks via Plug.Conn.chunk. Formato: data: {json}\n\n. Primer chunk incluye elpaso metadata. Termina con data: [DONE]\n\n.
3. Formato respuesta no-streaming: OpenAI estándar + objeto "elpaso" con session_id, routing_decision, context_layers_used, model_switched.

4. Errores estructurados: elpaso_503 (no models), elpaso_504 (timeout cold start), elpaso_422 (bad request), elpaso_500 (internal), model_error (502). Formato: {"error": {"message", "type", "code", "param"}.

5. ElPaso.Security:
   - API key local: si system.api_key configurado, verificar Authorization: Bearer. Si no configurado, acceso libre.
   - Rate limiting: token bucket en ETS, system.rate_limit_rpm (default 60), respuesta 429.
   - Sanitización: system.max_message_length_chars (default 32768), respuesta 422.
   - CORS: configurable en system.cors_enabled.

6. Pipeline completo: request → auth → rate limit → parse → route → ensure_hot → build context → infer → persist → respond

Ejecuta mix compile para verificar.
PROMPT
)

if ! run_block "coder" "HTTP Layer + Seguridad" "$PROMPT_B7"; then
    echo -e "${RED}✗  Error crítico en V1.0 Bloque 7. Deteniendo.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# BLOQUE 8: Config Wizard + CLI + Telemetría (coder)
# ---------------------------------------------------------------------------
PROMPT_B8=$(cat <<'PROMPT'
Eres un desarrollador Elixir experto. Implementa el Wizard y CLI de ElPaso.

Lee Documentacion/v1.0.md sección "Config.Wizard" y "Telemetría". Zaguan está en ~/proyectos/zaguan — consulta lib/zaguan/ui/components/ y lib/zaguan/drawer/components/ para la API de UI.

IMPLEMENTA:

1. ElPaso.Config.Wizard con Zaguan.UI.Components (Input, Select, Confirm) y Zaguan.Drawer.Components (Header, Table, Message):
   - run/0: flujo de 8 pasos:
     P1: Header + EnvironmentDetector (GPUs, RAM, binarios)
     P2: System config (puerto, log level)
     P3: DB config (PostgreSQL URL, verificar conexión)
     P4: Primer modelo (nombre, fuente local/remoto, GGUF path, engine, args, chat template, rol)
     P5: ¿Más modelos?
     P6: System prompt (inline o path a archivo)
     P7: Revisión JSON + validación
     P8: Test arranque opcional
   - 3 modos: crear, editar (--edit), add-model

2. ElPaso.Config.EnvironmentDetector:
   - detect_gpus/0: nvidia-smi parsing
   - detect_ram_mb/0: /proc/meminfo
   - detect_cpu_threads/0: System.schedulers_online
   - find_binary/1: System.find_executable
   - next_available_port/1: intenta bind TCP

3. Mix tasks:
   - mix elpaso.setup → Wizard.run
   - mix elpaso.models → lista modelos y estado (Table con Zaguan)
   - mix elpaso.config.reload → reload con confirmación
   - mix elpaso.config.validate → valida sin modificar

4. Telemetría — attach handlers para TODOS los eventos:
   prefix:hit/miss, context:built/window_trimmed/compressed, router:decision/fallback,
   model:cold_start/health_check, inference:complete/error

Ejecuta mix compile para verificar.
PROMPT
)

if ! run_block "coder" "Config Wizard + CLI + Telemetría" "$PROMPT_B8"; then
    echo -e "${RED}✗  Error crítico en V1.0 Bloque 8. Deteniendo.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Commit y tag
# ---------------------------------------------------------------------------
git_commit "feat(v1.0): sistema funcional local completo"
git_tag "v1.0"

echo ""
echo -e "${GREEN}${BOLD}✓ V1.0 completada — 8 bloques ejecutados${NC}"
