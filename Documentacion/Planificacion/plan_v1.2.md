# Plan V1.2 — Diagnóstico y Ajuste Fino

> **Spec**: [v1.2.md](../v1.2.md) | **Prerequisito**: V1.1 completo

## Objetivo
El usuario entiende qué hace el router, detecta problemas y ajusta comportamiento con datos reales.

---

## BLOQUE 1 — RouterStats + Bench + Export (coder)

**Modelo**: `coder` | **Estimación**: ~25 min

**Tareas**:
1. `Storage.query_routing_decisions/1` — query SQL con filtros (since, model, task_type)
2. `ElPaso.Domain.RouterStats`: aggregate/1, struct RouterStatsReport (total, fallback_count/rate, by_task_type, by_model con avg/p95 latency, cold_starts, errors)
3. `ElPaso.CLI.Commands.RouterStats`: mix elpaso router stats con Zaguan (--since, --model, --task-type, --format json)
4. `ElPaso.CLI.Commands.Bench`: mix elpaso bench con prompts por task_type (7 defaults), InternalClient, barra progreso, resumen TTFT/latencia/cache hits
5. `ElPaso.CLI.Commands.Context.export/2`: markdown y JSON con historial completo + archivados

**Ref**: Secciones 1.2.1, 1.2.3, 1.2.5 de v1.2.md

---

## BLOQUE 2 — RouterTuner + Config.Diff (r1)

**Modelo**: `r1` | **Estimación**: ~30 min

**Tareas**:
1. `ElPaso.Domain.RouterTuner`: analyze/1, AffinitySuggestion struct, calculate_suggested_affinity (success_rate×0.7 + latency_score×0.3, inercia 0.4/0.6), calculate_confidence (n_factor + variance_factor), min_decisions=20, min_confidence=0.6, min_delta=0.05
2. `mix elpaso router tune` — wizard interactivo: muestra sugerencias, [S]iguiente/[A]plicar/[R]echazar, aplicación en caliente via Config.Loader.update_affinity
3. `ElPaso.Config.Diff`: diff/2, flatten configs, classify_impact (hot_reload/requires_model_restart/requires_full_restart), ConfigChange struct
4. Actualizar mix elpaso config reload para mostrar diff con impacto antes de aplicar

**Ref**: Secciones 1.2.2, 1.2.4 de v1.2.md

---

## Resumen

| Bloque | Modelo | Descripción            | Dep    |
|--------|--------|------------------------|--------|
| 1      | coder  | Stats + Bench + Export | V1.1   |
| 2      | r1     | Tuner + Diff           | B1     |

**Cambios de modelo**: 1 (coder→r1)
