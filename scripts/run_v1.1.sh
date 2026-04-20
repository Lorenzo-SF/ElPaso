#!/usr/bin/env bash
# =============================================================================
# run_v1.1.sh — Automatización ElPaso V1.1: Madurez Operacional
# =============================================================================
source "$(dirname "$0")/common.sh"

version_header "V1.1" "Madurez Operacional y Contexto Semántico"

# ---------------------------------------------------------------------------
# BLOQUE 1: Embeddings + SemanticRetriever (coder)
# ---------------------------------------------------------------------------
PROMPT_B1=$(cat <<'PROMPT'
Eres un desarrollador Elixir experto. Implementa la Capa 3 (semántica) del Portable Session Context de ElPaso.

Lee Documentacion/v1.1.md sección 1.1.1 completa.

IMPLEMENTA:

1. ElPaso.Context.EmbeddingClient:
   - embed/1: genera embedding via POST al endpoint /v1/embeddings del modelo configurado en embeddings.model_id. Usa Finch.
   - embed_batch/1: lote de textos en una llamada
   - ping/0: verifica disponibilidad del modelo de embeddings
   - dimensions/0: devuelve dimensión del vector

2. ElPaso.Context.SemanticRetriever:
   - search/4 (session_id, query_text, k, min_similarity): genera embedding del query, busca coseno en mensajes archivados con pgvector (<=>). Solo archived_at IS NOT NULL. Default min_similarity: 0.75.
   - search_by_vector/4: búsqueda con embedding ya calculado

3. Actualizar ElPaso.Context.Manager.get_context_layers/2:
   - Si semantic_retrieval enabled y pgvector available: genera embedding del último mensaje user, busca K=5 similares, trunca a semantic_budget.
   - Fallo silencioso: si error, devuelve [] sin bloquear.

4. Migraciones:
   - Índice IVFFlat (CONCURRENTLY, manual post-100 filas): CREATE INDEX idx_messages_embedding_ivfflat ON messages USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100) WHERE embedding IS NOT NULL
   - Tabla embedding_stats: session_id UUID PK FK, total_archived INT, with_embedding INT, last_updated_at

5. Generación async en append_turn/4: Task.start(fn -> EmbeddingClient.embed(content) |> Storage.save_embedding end). Fire-and-forget. Si falla, embedding queda NULL.

6. Telemetría: embedding:generated (duration_ms, dimensions), embedding:failed, semantic:search (duration_ms, results_count)

7. CLI ElPaso.CLI.Commands.Embeddings:
   - mix elpaso embeddings rebuild: mensajes con embedding IS NULL, lotes de 50, progreso con Zaguan.Bar
   - mix elpaso embeddings stats: cobertura, índice, modelo activo

8. Config sección embeddings: enabled, model_id, dimensions 768, timeout 5000, batch_size 50, semantic_retrieval_k 5, min_similarity_threshold 0.75. Modelo con role: "embeddings" excluido del router.

Ejecuta mix compile para verificar.
PROMPT
)

run_block "coder" "Embeddings + SemanticRetriever" "$PROMPT_B1"

# ---------------------------------------------------------------------------
# BLOQUE 2: Tokenizadores reales (coder)
# ---------------------------------------------------------------------------
PROMPT_B2=$(cat <<'PROMPT'
Eres un desarrollador Elixir experto. Implementa tokenizadores reales para ElPaso.

Lee Documentacion/v1.1.md sección 1.1.2.

IMPLEMENTA:

1. ElPaso.Context.Tokenizer:
   - register/2 (model_id, config): registra tokenizador en ETS
   - count/2 (text, model_id): usa backend registrado. Si tiktoken → Port Python. Si no registrado → fallback TokenCounter.estimate/1. Retorna {:ok, n} o {:fallback, n}.
   - info/1, list/0
   - TokenizerConfig struct: backend (:tiktoken | :estimate), model_name

2. priv/python/tokenizer_server.py: script Python que lee líneas JSON stdin {"text": "...", "model": "gpt-4"}, responde {"count": 42}. import tiktoken. Maneja errores.

3. Registro en ModelWorker: al arrancar modelo, llama Tokenizer.register con backend según context_spec.tokenizer ("tiktoken" o "estimate").

4. Context.Builder: usa Tokenizer.count/2 en vez de TokenCounter. Margen seguridad 5% si {:ok, n}, 15% si {:fallback, n}.

Ejecuta mix compile para verificar.
PROMPT
)

run_block "coder" "Tokenizadores reales" "$PROMPT_B2"

# ---------------------------------------------------------------------------
# BLOQUE 3: Session overrides + Context show + Migrator (thinker)
# ---------------------------------------------------------------------------
PROMPT_B3=$(cat <<'PROMPT'
Eres un arquitecto Elixir experto. Implementa session overrides, visualización de contexto y migrador de config.

Lee Documentacion/v1.1.md secciones 1.1.3, 1.1.4, 1.1.5.

IMPLEMENTA:

1. ElPaso.HTTP.RequestParser:
   - parse_chat_request/1: extrae campo "elpaso" del body si existe
   - SessionOverrides struct: session_id, context_mode, window_size, force_model, latency_tolerance_ms, summarize_with_model
   - Integrar en pipeline HTTP

2. Aplicación de overrides:
   - force_model: bypass completo del scoring en Router.route/3
   - window_size/context_mode: actualizar SessionState en ETS
   - latency_tolerance_ms: pasar a ensure_hot
   - summarize_with_model: override en SummarizationWorker

3. ElPaso.CLI.Commands.Context:
   - show/2 (session_id, opts): con Zaguan Table muestra 3 capas (canónico, resumen, ventana) con tokens. Calcula budget disponible por modelo. Soporte --format json.

4. ElPaso.Config.Migrator:
   - migrate/3 (config, from, to): aplica path de migración
   - Migración 1.0→1.1: añade sección embeddings (enabled:false), tokenizer:"estimate" y supports_vision:false a cada modelo
   - mix elpaso config migrate: detecta versión actual, muestra cambios, backup auto, pide confirmación

Ejecuta mix compile para verificar.
PROMPT
)

run_block "thinker" "Session overrides + Context show + Migrator" "$PROMPT_B3"

# ---------------------------------------------------------------------------
git_commit "feat(v1.1): madurez operacional — embeddings, tokenizers, overrides"
git_tag "v1.1"
echo -e "${GREEN}${BOLD}✓ V1.1 completada${NC}"
