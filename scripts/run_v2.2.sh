#!/usr/bin/env bash
# =============================================================================
# run_v2.2.sh — Automatización ElPaso V2.2: Aprendizaje Adaptativo
# =============================================================================
source "$(dirname "$0")/common.sh"

version_header "V2.2" "Aprendizaje Adaptativo del Router"

# --- BLOQUE 1: RouterAnalyzer + Detección retry (r1) ---
PROMPT_B1=$(cat <<'PROMPT'
Implementa análisis estadístico avanzado del router de ElPaso. Lee Documentacion/v2.2.md secciones 2.2.1 y 2.2.2.

1. ElPaso.Domain.RouterAnalyzer:
   - analyze_trends/1 (since :last_30d): agrupa routing_decisions por (model, task_type), divide en ventanas semanales, calcula success_rate por ventana.
   - calculate_trend: regresión lineal simple sobre tasas semanales. slope > 0.02 → :improving, < -0.02 → :degrading, else :stable.
   - calculate_retry_rate: dos decisiones misma sesión en <10s = retry. Porcentaje sobre total.
   - CombinationAnalysis struct: model_id, task_type, n_decisions, overall_success_rate, success_trend, median_latency_ms, retry_rate_pct, alert.
   - should_alert?: retry_rate > 30% con n > 20.

2. AffinitySuggestion extendida: añadir trend, retry_rate_pct, weekly_breakdown [{week, success_rate, n}], auto_appliable (confianza > 0.85 y n > 50).

3. linear_regression_slope/1: implementación simple con fórmula de mínimos cuadrados sobre lista de floats.

Ejecuta mix compile para verificar.
PROMPT
)
run_block "r1" "RouterAnalyzer + Detección retry" "$PROMPT_B1"

# --- BLOQUE 2: AutoTuner + Alertas (coder) ---
PROMPT_B2=$(cat <<'PROMPT'
Implementa auto-tuning y alertas de degradación para ElPaso. Lee Documentacion/v2.2.md secciones 2.2.3 y 2.2.4.

1. ElPaso.Domain.AutoTuner (GenServer):
   - handle_info :run_auto_tune: si auto_tune enabled, RouterAnalyzer.analyze_trends, filtrar auto_appliable, aplicar via Config.Loader.update_affinity, emitir telemetría router:auto_tuned, guardar en Storage.save_auto_tune_run.
   - schedule_next_run: Process.send_after con check_interval_hours.
   - Config routing: auto_tune true/false, auto_tune_min_confidence 0.85, auto_tune_min_decisions 50, auto_tune_check_interval_hours 24.

2. Migración tabla auto_tune_runs: id BIGSERIAL, applied_count INT, suggestions JSONB, applied_at TIMESTAMPTZ.

3. Alertas degradación: evento router:quality_alert cuando retry_rate > 30% + n > 20. Aparece en Logger :warning, /status campo alerts[], dashboard notificación.

4. mix elpaso router tune --revert-auto: lee último auto_tune_run, revierte las afinidades al valor anterior.

Ejecuta mix compile para verificar.
PROMPT
)
run_block "coder" "AutoTuner + Alertas" "$PROMPT_B2"

git_commit "feat(v2.2): aprendizaje adaptativo del router"
git_tag "v2.2"
echo -e "${GREEN}${BOLD}✓ V2.2 completada${NC}"
