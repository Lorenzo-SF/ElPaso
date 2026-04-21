#!/usr/bin/env bash
# =============================================================================
# run_v1.3.sh — Automatización ElPaso V1.3: Observabilidad y Multi-usuario
# =============================================================================
source "$(dirname "$0")/common.sh"

version_header "V1.3" "Observabilidad y Multi-usuario Básico"

# ---------------------------------------------------------------------------
# BLOQUE 1: Dashboard HTML + Telemetry.Store (gemma)
# ---------------------------------------------------------------------------
PROMPT_B1=$(cat <<'PROMPT'
Eres un experto en HTML, CSS y JavaScript vanilla. Implementa el dashboard web de ElPaso.

Lee Documentacion/v1.3.md sección 1.3.1.

IMPLEMENTA:

1. ElPaso.Telemetry.Store (GenServer):
   - init: :telemetry.attach_many para eventos: prefix:hit/miss, inference:complete/error, model:cold_start, router:fallback
   - Estado: :queue de eventos (max 100), counters prefix_hits/misses
   - recent_events/1: últimos N eventos
   - prefix_cache_hit_ratio/0: hits / (hits + misses)

2. ElPaso.HTTP.Dashboard (Plug.Router):
   - GET / → HTML+CSS+JS embebido como string en el módulo
   - GET /api/state → JSON con: models (estados), sessions (active count, tokens_24h), router (decisions_1h, fallback_rate), prefix_cache (hit_ratio), recent_events(10)
   - El HTML debe ser VISUALMENTE ATRACTIVO: diseño oscuro, cards con colores por estado (verde=hot, amarillo=warming, gris=cold, rojo=error), métricas en grid, timeline de eventos, auto-refresh cada 5s con fetch. CSS moderno con bordes redondeados, sombras, transiciones. NO usar frameworks externos.

3. Montar en HTTP.Router principal: forward "/dashboard" → Dashboard

Ejecuta mix compile para verificar.
PROMPT
)

if ! run_block "gemma" "Dashboard HTML + Telemetry.Store" "$PROMPT_B1"; then
    echo -e "${RED}✗  Error crítico en V1.3 Bloque 1. Deteniendo.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# BLOQUE 2: Prometheus + WebSocket (coder)
# ---------------------------------------------------------------------------
PROMPT_B2=$(cat <<'PROMPT'
Eres un desarrollador Elixir experto. Implementa Prometheus y WebSocket para ElPaso.

Lee Documentacion/v1.3.md secciones 1.3.2 y 1.3.4.

IMPLEMENTA:

1. ElPaso.Telemetry.PrometheusExporter: métricas declarativas con telemetry_metrics_prometheus:
   - counter elpaso.inference.complete.total (tags: model_id, task_type)
   - distribution elpaso.inference.complete.latency_ms (buckets: 100,500,1000,2000,5000,10000)
   - last_value elpaso.model.status (1=hot, 0.5=warming, 0=other)
   - counter elpaso.router.fallback.total (tags: reason)
   - last_value elpaso.prefix.cache_hit_ratio
   - distribution elpaso.model.cold_start.startup_duration_ms

2. GET /metrics endpoint para scraping Prometheus

3. ElPaso.HTTP.WebSocketHandler (@behaviour :cowboy_websocket):
   - init: extraer session_id de query string, autenticar
   - websocket_init: get_or_create_session
   - websocket_handle {:text, json}: parsear, ejecutar pipeline, streaming via frames
   - websocket_info: enviar chunks como {:text, json}
   - Montar en /v1/chat/ws

4. Migración add_user_id_to_sessions: ALTER TABLE sessions ADD COLUMN user_id TEXT

Ejecuta mix compile para verificar.
PROMPT
)

if ! run_block "coder" "Prometheus + WebSocket" "$PROMPT_B2"; then
    echo -e "${RED}✗  Error crítico en V1.3 Bloque 2. Deteniendo.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# BLOQUE 3: Auth + Rate Limiting (thinker)
# ---------------------------------------------------------------------------
PROMPT_B3=$(cat <<'PROMPT'
Eres un arquitecto Elixir experto en seguridad. Implementa autenticación multi-usuario para ElPaso.

Lee Documentacion/v1.3.md sección 1.3.3.

IMPLEMENTA:

1. ElPaso.Security.Auth:
   - authenticate/1 (api_key): auth disabled → {:ok, "anonymous"}. Key nil + allow_anonymous → {:ok, "anonymous"}. Key nil → {:error, :missing}. Key válida → {:ok, user_id}. Key inválida → {:error, :invalid}.
   - extract_api_key/1 (conn): parsea Authorization: Bearer <key>
   - Config auth: enabled, allow_anonymous, users (lista con id, api_key, max_rpm)

2. ElPaso.HTTP.AuthPlug:
   - call: extract key → authenticate → assign :current_user_id o 401 con error OpenAI format
   - Insertar en pipeline HTTP antes de dispatch

3. ElPaso.Security.RateLimiter:
   - Token bucket en ETS :rate_limiter por user_id
   - check_rate/2 (user_id, max_rpm): refill proporcional al tiempo, consume 1 token. :ok o {:error, :rate_limited}
   - HTTP 429 cuando rate limited

4. Aislamiento sesiones: session_id = "#{user_id}-#{uuid}". Storage queries filtran por user_id prefix. Campo user_id en sessions usado para índices.

Ejecuta mix compile para verificar.
PROMPT
)

if ! run_block "thinker" "Auth + Rate Limiting" "$PROMPT_B3"; then
    echo -e "${RED}✗  Error crítico en V1.3 Bloque 3. Deteniendo.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Commit y tag
# ---------------------------------------------------------------------------
git_commit "feat(v1.3): observabilidad — dashboard, prometheus, auth, websocket"
git_tag "v1.3"
echo -e "${GREEN}${BOLD}✓ V1.3 completada${NC}"
