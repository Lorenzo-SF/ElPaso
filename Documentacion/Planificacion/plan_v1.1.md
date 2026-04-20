# Plan V1.1 — Madurez Operacional y Contexto Semántico

> **Spec**: [v1.1.md](../v1.1.md) | **Prerequisito**: V1.0 funcional

## Objetivo
Sesiones largas sin pérdida de coherencia, tokenización precisa, overrides por request, visibilidad del contexto.

---

## BLOQUE 1 — Embeddings + SemanticRetriever + pgvector (coder)

**Modelo**: `coder` | **Estimación**: ~30 min

**Tareas**:
1. `ElPaso.Context.EmbeddingClient`: embed/1, embed_batch/1, ping/0, dimensions/0 — comunicación con /v1/embeddings
2. `ElPaso.Context.SemanticRetriever`: search/4 con coseno pgvector (`<=>`), search_by_vector/4, min_similarity 0.75
3. Actualizar Context.Manager.get_context_layers/2 con capa semántica
4. Migración IVFFlat index (manual post-100 filas) + tabla embedding_stats
5. Generación async de embeddings en append_turn/4 (Task.start fire-and-forget)
6. Telemetría: embedding:generated/failed, semantic:search
7. CLI: mix elpaso embeddings rebuild (lotes 50) + mix elpaso embeddings stats
8. Config sección embeddings: enabled, model_id, dimensions, thresholds
9. Modelo embeddings con role: "embeddings" excluido del router

**Ref**: Sección 1.1.1 de v1.1.md

---

## BLOQUE 2 — Tokenizadores reales (coder)

**Modelo**: `coder` | **Estimación**: ~20 min

**Tareas**:
1. `ElPaso.Context.Tokenizer`: register/2, count/2, info/1, list/0; TokenizerConfig struct
2. `priv/python/tokenizer_server.py` — Port Python para tiktoken, protocolo JSON lines
3. Registro en ModelWorker al arrancar (register_tokenizer/1)
4. Context.Builder usa Tokenizer.count/2: margen 5% preciso vs 15% fallback

**Ref**: Sección 1.1.2 de v1.1.md

---

## BLOQUE 3 — Session overrides + Context show + Migrator (thinker)

**Modelo**: `thinker` | **Estimación**: ~25 min

**Tareas**:
1. `ElPaso.HTTP.RequestParser` con extracción campo elpaso → SessionOverrides struct
2. Aplicación overrides: force_model bypass router, window_size/context_mode en SessionState, latency_tolerance_ms en ensure_hot
3. `ElPaso.CLI.Commands.Context`: mix elpaso context show — 3 capas con Zaguan, budget por modelo
4. `ElPaso.Config.Migrator`: migrate/3, migración 1.0→1.1 (embeddings, tokenizer, supports_vision), mix elpaso config migrate con backup

**Ref**: Secciones 1.1.3-1.1.5 de v1.1.md

---

## Resumen

| Bloque | Modelo  | Descripción                     | Dep    |
|--------|---------|---------------------------------|--------|
| 1      | coder   | Embeddings + Semantic           | V1.0   |
| 2      | coder   | Tokenizadores                   | V1.0   |
| 3      | thinker | Overrides + Context + Migrator  | B1,2   |

**Cambios de modelo**: 1 (coder→thinker)
