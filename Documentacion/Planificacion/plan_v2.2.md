# Plan V2.2 — Aprendizaje Adaptativo del Router

> **Spec**: [v2.2.md](../v2.2.md) | **Prerequisito**: V1.2 (RouterStats + RouterTuner) + 500 routing_decisions

## Objetivo
El router mejora automáticamente con el uso, con supervisión del usuario para aprobar cambios.

---

## BLOQUE 1 — RouterAnalyzer + Detección retry (r1)

**Modelo**: `r1` | **Estimación**: ~30 min

**Tareas**:
1. `ElPaso.Domain.RouterAnalyzer`: analyze_trends/1, ventanas semanales, regresión lineal simple sobre tasas de éxito, trend :improving/:stable/:degrading (slope > 0.02 / < -0.02)
2. calculate_retry_rate: dos mensajes misma sesión en <10s = retry, agrupar por session_id, detectar retries
3. CombinationAnalysis struct: model_id, task_type, n_decisions, overall_success_rate, success_trend, median_latency_ms, retry_rate_pct, alert
4. should_alert?: retry_rate > 30% con n > 20
5. AffinitySuggestion extendida: trend, retry_rate_pct, weekly_breakdown, auto_appliable (confianza > 0.85, n > 50)

**Ref**: Secciones 2.2.1, 2.2.2 de v2.2.md

---

## BLOQUE 2 — AutoTuner + Alertas + Migración (coder)

**Modelo**: `coder` | **Estimación**: ~25 min

**Tareas**:
1. `ElPaso.Domain.AutoTuner` (GenServer): handle_info :run_auto_tune periódico, filtra auto_appliable, aplica via Config.Loader.update_affinity, telemetría router:auto_tuned, save_auto_tune_run
2. Config routing.auto_tune: enabled, min_confidence 0.85, min_decisions 50, check_interval_hours 24
3. Migración tabla auto_tune_runs (id, applied_count, suggestions JSONB, applied_at)
4. Alertas degradación: evento router:quality_alert cuando retry_rate > 30% + n > 20, aparece en: Logger :warning, /status campo alerts[], dashboard notificación
5. mix elpaso router tune --revert-auto: deshace último auto-tune

**Ref**: Secciones 2.2.3, 2.2.4 de v2.2.md

---

## Resumen

| Bloque | Modelo | Descripción                  | Dep  |
|--------|--------|------------------------------|------|
| 1      | r1     | Analyzer + Retry detection   | V1.2 |
| 2      | coder  | AutoTuner + Alertas          | B1   |

**Cambios de modelo**: 1 (r1→coder)
