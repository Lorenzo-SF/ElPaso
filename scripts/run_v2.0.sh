#!/usr/bin/env bash
# =============================================================================
# run_v2.0.sh — Automatización ElPaso V2.0: Integraciones y Extensibilidad
# =============================================================================
source "$(dirname "$0")/common.sh"

version_header "V2.0" "Integraciones Externas y Extensibilidad"

# ---------------------------------------------------------------------------
# BLOQUE 1: AnthropicProxy + Claude Code (thinker)
# ---------------------------------------------------------------------------
PROMPT_B1=$(cat <<'PROMPT'
Eres un arquitecto Elixir experto. Implementa la integración con Claude Code para ElPaso.

Lee Documentacion/v2.0.md sección 2.0.1.

IMPLEMENTA:

1. ElPaso.HTTP.AnthropicProxy:
   - from_anthropic/1: convierte request Anthropic (model, messages, system, max_tokens, stream) a formato interno InternalRequest
   - to_anthropic/2: convierte respuesta interna a formato Anthropic (id msg_xxx, type message, content [{type text, text ...}], stop_reason, usage)
   - to_anthropic_stream_chunk/2: SSE Anthropic con event types:
     :start → message_start {role assistant}
     :delta → content_block_delta {type text_delta, text chunk}
     :stop → message_delta {stop_reason end_turn, usage}
   - map_anthropic_model/1: lee integrations.claude_code.model_mapping
2. POST /v1/messages en HTTP.Router: mismo pipeline que chat/completions pero con conversión Anthropic↔interno
3. Config integrations.claude_code: enabled, policy (prefer_local → penalización 0.2 a remotos), fallback_to_remote, model_mapping (claude-opus→heavy, claude-sonnet→fast, etc.)

Ejecuta mix compile para verificar.
PROMPT
)

if ! run_block "thinker" "AnthropicProxy + Claude Code" "$PROMPT_B1"; then
    echo -e "${RED}✗  Error crítico en V2.0 Bloque 1. Deteniendo.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# BLOQUE 2: Plugins + Downloader + Visión (coder)
# ---------------------------------------------------------------------------
PROMPT_B2=$(cat <<'PROMPT'
Eres un desarrollador Elixir experto. Implementa plugins, descarga de modelos y soporte visión para ElPaso.

Lee Documentacion/v2.0.md secciones 2.0.2, 2.0.3, 2.0.4.

IMPLEMENTA:

1. ElPaso.Engine behaviour público:
   @callback name() :: atom()
   @callback type() :: :local_process | :remote_api
   @callback infer(prompt, params, config) :: {:ok, Response.t()} | {:error, reason}
   @callback stream(prompt, params, config, callback) :: :ok | {:error, reason}
   @callback prepare_prefix(prefix, config) :: term()
   @callback health_check(config) :: :ok | {:error, reason}
   @callback format_messages(messages, spec) :: term()
   Structs: Engine.Response (content, finish_reason, prompt/completion_tokens, latency_ms), Engine.Chunk (content, done, tokens)

2. ElPaso.Plugin.Loader: load_all/1 recorre config plugins.engines. load_engine_plugin/1: Code.compile_file, valida callbacks name/0 + infer/3, registra en Engine.Registry. Log warning si falta.

3. ElPaso.Engine.Registry: GenServer con mapa de engines registrados. register/2, lookup/1.

4. Plugin de ejemplo: priv/plugins/echo_engine.ex — devuelve el input como output.

5. ElPaso.ModelDownloader: download/2 con Finch.stream para streaming HTTP, DownloadRegistry en ETS para progreso, verify_checksum SHA256. progress/1. mix elpaso models download <model_id>.

6. Soporte visión:
   - FeatureVector: has_image_input, image_count (ya en types.ex)
   - Feature extraction: detectar content tipo lista con image_url
   - Context.Builder: mensajes con imagen nunca salen de ventana (:keep_in_window)
   - Scorer: capability_multiplier 0.0 si modelo no tiene supports_vision y request tiene imagen

Ejecuta mix compile para verificar.
PROMPT
)

if ! run_block "coder" "Plugins + Downloader + Visión" "$PROMPT_B2"; then
    echo -e "${RED}✗  Error crítico en V2.0 Bloque 2. Deteniendo.${NC}"
    exit 1
fi

# ---------------------------------------------------------------------------
# git_commit y git_tag
# ---------------------------------------------------------------------------
git_commit "feat(v2.0): integraciones — claude code, plugins, downloader, visión"
git_tag "v2.0"
echo -e "${GREEN}${BOLD}✓ V2.0 completada${NC}"
