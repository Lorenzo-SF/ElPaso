# Plan V1.3 — Observabilidad y Multi-usuario Básico

> **Spec**: [v1.3.md](../v1.3.md) | **Prerequisito**: V1.2 completo

## Objetivo
ElPaso observable desde Grafana/Prometheus, uso compartido en red local con multi-usuario.

---

## BLOQUE 1 — Dashboard HTML + Telemetry.Store (gemma)

**Modelo**: `gemma` | **Estimación**: ~30 min

**Tareas**:
1. `ElPaso.Telemetry.Store` (GenServer): suscripción a 6 eventos principales, buffer en ETS con :queue, prefix_cache_hit_ratio/0, recent_events/1
2. `ElPaso.HTTP.Dashboard` (Plug): HTML+CSS+JS vanilla embebido como string, polling fetch /dashboard/api/state cada 5s, actualización DOM
3. API endpoint GET /dashboard/api/state: modelos (states), sesiones (active, tokens_24h), router (decisions_1h, fallback_rate), prefix_cache (hit_ratio), recent_events(10)
4. Diseño visual: estado modelos con colores (hot=verde, warming=amarillo, cold=gris, error=rojo), métricas en cards, eventos en timeline

**Ref**: Sección 1.3.1 de v1.3.md

---

## BLOQUE 2 — Prometheus + WebSocket (coder)

**Modelo**: `coder` | **Estimación**: ~25 min

**Tareas**:
1. `ElPaso.Telemetry.PrometheusExporter`: métricas declarativas (counter inference.complete.total, distribution latency_ms con buckets, last_value model.status, counter fallback.total, last_value cache_hit_ratio, distribution cold_start.startup_duration_ms)
2. Endpoint GET /metrics para scraping
3. `ElPaso.HTTP.WebSocketHandler` (cowboy_websocket): init con session_id + auth, websocket_handle {:text, json}, streaming via websocket frames, websocket_info para chunks
4. Migración add_user_id_to_sessions (columna user_id nullable en sessions)

**Ref**: Secciones 1.3.2, 1.3.4 de v1.3.md

---

## BLOQUE 3 — Auth + Rate Limiting (thinker)

**Modelo**: `thinker` | **Estimación**: ~20 min

**Tareas**:
1. `ElPaso.Security.Auth`: authenticate/1 (enabled? → api_key? → find_user), extract_api_key/1 (Authorization: Bearer), multi-user con config auth.users
2. `ElPaso.HTTP.AuthPlug`: plug call → authenticate → assign :current_user_id o 401 con formato error estándar
3. `ElPaso.Security.RateLimiter`: token bucket por user_id en ETS, check_rate/2, refill proporcional al tiempo
4. Aislamiento sesiones: session_id = "#{user_id}-#{uuid}", filtro en Storage queries

**Ref**: Sección 1.3.3 de v1.3.md

---

## Resumen

| Bloque | Modelo  | Descripción            | Dep  |
|--------|---------|------------------------|------|
| 1      | gemma   | Dashboard + Store      | V1.2 |
| 2      | coder   | Prometheus + WebSocket | V1.2 |
| 3      | thinker | Auth + Rate Limiting   | B2   |

**Cambios de modelo**: 2 (gemma→coder, coder→thinker)
