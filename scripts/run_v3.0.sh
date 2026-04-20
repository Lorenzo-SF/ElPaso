#!/usr/bin/env bash
# =============================================================================
# run_v3.0.sh — Automatización ElPaso V3.0: ElPaso como Servicio
# =============================================================================
source "$(dirname "$0")/common.sh"

version_header "V3.0" "ElPaso como Servicio"

# --- BLOQUE 1: CostManager + JWT (thinker) ---
PROMPT_B1=$(cat <<'PROMPT'
Implementa gestión de costes y JWT para ElPaso. Lee Documentacion/v3.0.md secciones 3.0.1 y 3.0.2.

1. Migraciones: model_pricing (model_id TEXT, input/output_price_per_1k DECIMAL(10,6), valid_from/until DATE, PK model_id+valid_from). api_usage (id BIGSERIAL, user_id TEXT, model_id TEXT, date DATE, input/output_tokens BIGINT, cost_usd DECIMAL(10,6), request_count INT, UNIQUE user_id+model_id+date). Índices en user_id+date y model_id+date.

2. Schemas Ecto: ModelPricing, ApiUsage con tipos Decimal.

3. ElPaso.CostManager: record_usage/4 (calcula coste, upsert api_usage), check_budget/1 (daily_spend vs config daily_usd → :budget_exceeded/:approaching_budget/:ok), remote_model_penalty/1 (exceeded→999.0, approaching→0.3, ok→0.0). Integrar penalty en Router scoring.

4. ElPaso.Security.JWT: generate_token/2 con JOSE (HS256, claims sub/role/iat/exp 24h, secret desde ELPASO_JWT_SECRET env), verify_token/1 con expiración.

5. POST /auth/token: recibe user_id + api_key, valida, devuelve JWT.

6. AuthPlug: acepta JWT (verify_token) además de API keys estáticas.

7. Config cost_management: daily_usd, alert_at_pct.

Ejecuta mix compile para verificar.
PROMPT
)
run_block "thinker" "CostManager + JWT" "$PROMPT_B1"

# --- BLOQUE 2: S3Adapter + API Admin (coder) ---
PROMPT_B2=$(cat <<'PROMPT'
Implementa S3 y API admin para ElPaso. Lee Documentacion/v3.0.md secciones 3.0.3 y 3.0.4.

1. ElPaso.Storage.S3Adapter: download_model/2 (ExAws.S3.download_file streaming), backup_config/2 (File.stream! → ExAws.S3.upload). source.type "s3" en config: uri, local_cache_path. ModelManager verifica/descarga al arrancar.

2. AdminAuthPlug: verifica role: :admin en JWT, 403 sin él.

3. API Admin bajo /admin:
   POST /admin/models/:id/enable, POST /admin/models/:id/disable
   GET /admin/sessions, DELETE /admin/sessions/:id
   GET /admin/users, POST /admin/users, DELETE /admin/users/:id
   GET /admin/usage/report (filtros period, user_id, model_id)
   GET /admin/usage/report.csv

Ejecuta mix compile para verificar.
PROMPT
)
run_block "coder" "S3Adapter + API Admin" "$PROMPT_B2"

git_commit "feat(v3.0): ElPaso como servicio — costes, JWT, S3, admin"
git_tag "v3.0"
echo -e "${GREEN}${BOLD}✓ V3.0 completada — Proyecto ElPaso completo${NC}"
