#!/usr/bin/env bash
# =============================================================================
# run_v1.2.sh — Automatización ElPaso V1.2: Diagnóstico y Ajuste Fino
# =============================================================================
source "$(dirname "$0")/common.sh"

version_header "V1.2" "Diagnóstico y Ajuste Fino"

# ---------------------------------------------------------------------------
# BLOQUE 1: RouterStats + Bench + Export (coder)
# ---------------------------------------------------------------------------
PROMPT_B1=$(cat <<'PROMPT'
Eres un desarrollador Elixir experto. Implementa herramientas de diagnóstico para ElPaso.

Lee Documentacion/v1.2.md secciones 1.2.1, 1.2.3, 1.2.5.

IMPLEMENTA:

1. Storage.query_routing_decisions/1: query SQL con filtros (since datetime, selected_model, task_type). SELECT * FROM routing_decisions WHERE decided_at >= $1 AND optional filters. ORDER BY decided_at DESC.

2. ElPaso.Domain.RouterStats:
   - aggregate/1 (since: :last_hour | :last_24h | :last_7d): devuelve RouterStatsReport
   - RouterStatsReport struct: period, total_decisions, fallback_count, fallback_rate_pct, by_task_type (map con total y by_model con count/pct/avg_latency/p95), by_model (total_calls, success_rate, avg/p95 latency, errors), cold_starts, error_count, generated_at

3. ElPaso.CLI.Commands.RouterStats: mix elpaso router stats con opciones --since, --model, --task-type, --format json. Usa Zaguan Table para output.

4. ElPaso.CLI.Commands.Bench: mix elpaso bench --model <id> --requests 7. 7 prompts default por task_type. Barra progreso con Zaguan Bar. Resumen: TTFT, latencia total, cache hits, errores.

5. ElPaso.CLI.Commands.Context.export/2: mix elpaso context export <session_id> --format markdown|json. Incluye historial completo con archivados y resumen.

Ejecuta mix compile para verificar.
PROMPT
)

run_block "coder" "RouterStats + Bench + Export" "$PROMPT_B1"

# ---------------------------------------------------------------------------
# BLOQUE 2: RouterTuner + Config.Diff (r1)
# ---------------------------------------------------------------------------
PROMPT_B2=$(cat <<'PROMPT'
Eres un experto en razonamiento estadístico. Implementa el tuner del router de ElPaso.

Lee Documentacion/v1.2.md secciones 1.2.2, 1.2.4.

IMPLEMENTA:

1. ElPaso.Domain.RouterTuner:
   - analyze/1 (since): agrupa routing_decisions por (model, task_type), calcula sugerencias
   - AffinitySuggestion struct: model_id, task_type, current_affinity, suggested_affinity, delta, confidence, based_on_n_decisions, reason
   - calculate_suggested_affinity: performance_score = success_rate*0.7 + latency_score*0.3; resultado = current*0.4 + performance*0.6
   - calculate_confidence: n_factor = min(1.0, n/100); variance = 4*sr*(1-sr); n_factor*0.6 + variance*0.4
   - Filtros: min_decisions 20, min_confidence 0.6, min_delta 0.05

2. mix elpaso router tune --since 7d: muestra sugerencias ordenadas por confianza. Wizard interactivo: [S]iguiente, [A]plicar (Config.Loader.update_affinity en caliente), [R]echazar, [Q]salir.

3. ElPaso.Config.Diff:
   - diff/2 (old, new): flatten ambos configs, detecta added/removed/changed
   - classify_impact/1: models[*].engine_args → requires_model_restart, system.db_url → requires_full_restart, routing.* → hot_reload
   - ConfigChange struct: path, type, old_value, new_value, impact

4. Actualizar mix elpaso config reload: muestra diff con impacto clasificado antes de aplicar, pide confirmación.

Ejecuta mix compile para verificar.
PROMPT
)

run_block "r1" "RouterTuner + Config.Diff" "$PROMPT_B2"

# ---------------------------------------------------------------------------
git_commit "feat(v1.2): diagnóstico — stats, bench, tuner, diff"
git_tag "v1.2"
echo -e "${GREEN}${BOLD}✓ V1.2 completada${NC}"
