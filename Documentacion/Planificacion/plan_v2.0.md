# Plan V2.0 — Integraciones Externas y Extensibilidad

> **Spec**: [v2.0.md](../v2.0.md) | **Prerequisito**: V1.3 completo

## Objetivo
ElPaso como hub: Claude Code, plugins de engine, descarga HF Hub, visión multimodal.

---

## BLOQUE 1 — AnthropicProxy + Claude Code (thinker)

**Modelo**: `thinker` | **Estimación**: ~30 min

**Tareas**:
1. `ElPaso.HTTP.AnthropicProxy`: from_anthropic/1 (convertir request Anthropic→interno), to_anthropic/2 (respuesta interna→formato Anthropic), to_anthropic_stream_chunk/2 (SSE con event types: message_start, content_block_delta, message_delta)
2. Endpoint POST /v1/messages en HTTP.Router con pipeline completo
3. map_anthropic_model/1 con config integrations.claude_code.model_mapping
4. Config sección integrations.claude_code: enabled, policy (prefer_local), fallback_to_remote, model_mapping (claude-opus→heavy, claude-sonnet→fast, etc.)
5. Penalización 0.2 en score para modelos remotos cuando policy=prefer_local

**Ref**: Sección 2.0.1 de v2.0.md

---

## BLOQUE 2 — Plugin.Loader + Engine behaviour + Downloader + Visión (coder)

**Modelo**: `coder` | **Estimación**: ~35 min

**Tareas**:
1. `ElPaso.Engine` behaviour público: callbacks name/0, type/0, infer/3, stream/4, prepare_prefix/2, health_check/1, format_messages/2
2. Structs Engine.Response (content, finish_reason, tokens, latency_ms) y Engine.Chunk (content, done, tokens)
3. `ElPaso.Plugin.Loader`: load_all/1, load_engine_plugin/1 con Code.compile_file, validación behaviour, registro en Engine.Registry
4. `ElPaso.Engine.Registry`: registro dinámico, lookup/1
5. Plugin de ejemplo trivial (echo engine)
6. `ElPaso.ModelDownloader`: download/2 con Finch.stream, DownloadRegistry en ETS, progreso, verify_checksum SHA256, progress/1
7. mix elpaso models download CLI
8. Soporte visión: has_image_input/image_count en FeatureVector, detección imágenes en feature extraction, Context.Builder: mensajes con imagen nunca salen de ventana, capability_multiplier 0.0 para modelos sin supports_vision

**Ref**: Secciones 2.0.2, 2.0.3, 2.0.4 de v2.0.md

---

## Resumen

| Bloque | Modelo  | Descripción                           | Dep  |
|--------|---------|---------------------------------------|------|
| 1      | thinker | Claude Code proxy                     | V1.3 |
| 2      | coder   | Plugins + Downloader + Visión         | B1   |

**Cambios de modelo**: 1 (thinker→coder)
