# Plan V3.0 — ElPaso como Servicio

> **Spec**: [v3.0.md](../v3.0.md) | **Prerequisito**: V2.1 completo

## Objetivo
ElPaso desplegable como servicio compartido: costes, JWT, S3, API admin.

---

## BLOQUE 1 — CostManager + JWT (thinker)

**Modelo**: `thinker` | **Estimación**: ~30 min

**Tareas**:
1. Migraciones: model_pricing (model_id, input/output_price_per_1k DECIMAL, valid_from/until), api_usage (user_id, model_id, date, input/output_tokens BIGINT, cost_usd DECIMAL, request_count)
2. Schemas Ecto: ModelPricing, ApiUsage con tipos Decimal
3. `ElPaso.CostManager`: record_usage/4 (calcula coste, upsert api_usage), check_budget/1 (daily_spend vs config budget), remote_model_penalty/1 (exceeded→999.0, approaching→0.3, ok→0.0)
4. Integración con Router: sumar remote_model_penalty al scoring de modelos remotos
5. `ElPaso.Security.JWT`: generate_token/2 con JOSE (HS256, sub, role, iat, exp 24h), verify_token/1 con expiración
6. Endpoint POST /auth/token: recibe user_id+api_key, devuelve JWT
7. AuthPlug acepta tanto JWT como API keys estáticas
8. Config sección cost_management: daily_usd, alert_at_pct

**Ref**: Secciones 3.0.1, 3.0.2 de v3.0.md

---

## BLOQUE 2 — S3Adapter + API Admin (coder)

**Modelo**: `coder` | **Estimación**: ~25 min

**Tareas**:
1. `ElPaso.Storage.S3Adapter`: download_model/2 (ExAws.S3.download_file streaming), backup_config/2 (File.stream! → ExAws.S3.upload)
2. source.type "s3" en config: uri, local_cache_path; ModelManager verifica/descarga al arrancar
3. AdminAuthPlug: verifica role: :admin en JWT, 403 sin él
4. API Admin endpoints bajo /admin: POST models/:id/enable, POST models/:id/disable, GET sessions, DELETE sessions/:id, GET users, POST users, DELETE users/:id, GET usage/report, GET usage/report.csv
5. UsageController: reporte por usuario/modelo/período, export CSV

**Ref**: Secciones 3.0.3, 3.0.4 de v3.0.md

---

## Resumen

| Bloque | Modelo  | Descripción           | Dep  |
|--------|---------|-----------------------|------|
| 1      | thinker | CostManager + JWT     | V2.1 |
| 2      | coder   | S3 + Admin API        | B1   |

**Cambios de modelo**: 1 (thinker→coder)
