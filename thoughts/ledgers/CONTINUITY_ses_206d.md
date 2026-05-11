---
session: ses_206d
updated: 2026-05-11T12:12:36.992Z
---

# Session Summary

## Goal
Auditoría profunda y refactorización completa de ElPaso v4.0: fix del bug "gemma siempre gana", nuevo DecisionEngine semántico multi-capa, Sala Común de contexto compartido, compatibilidad dual OpenAI/Anthropic, sistema `elpaso doctor` con `--fix` autónomo, y migración de la gestión de paquetes a Apero como behaviour reutilizable con 7 implementaciones.

## Constraints & Preferences
- **NO tocar Zaguan** bajo ningún concepto (otro agente lo está arreglando)
- Usar Apero como toolkit: `Apero.Runner`, `Apero.Helpers`, `Apero.Net`, `Apero.Proc`, `Apero.Crypto`
- Modelo de embeddings obligatorio: `nomic-embed-text` (274 MB, 768-dim, multiidioma) como default, `bge-m3` (1.2 GB, 1024-dim) como upgrade opcional
- Docker con `pgvector/pgvector:pg17` (wrapper `~/bin/localdocker`)
- pgvector es OBLIGATORIO — primera migración debe crearlo automáticamente
- BD según `MIX_ENV`: `elpaso_dev`, `elpaso_test`, `elpaso_prod`

## Progress
### Done
- [x] **Fase 0 — Bootstrap**: `lib/el_paso/bootstrap.ex` — verifica Ollama + pgvector + descarga/selecciona modelo embeddings (dual: `nomic-embed-text` o `bge-m3`) antes de arrancar el servidor
- [x] **Fase 1 — Fundación**: Fix `extract_keywords` con n-gramas (unigrama+bigrama+trigrama), `find_best_match` con substring matching, `TaskCategories` extraído a módulo propio, `MessageNormalizer` para formatos OpenAI/Anthropic
- [x] **Fase 2 — DecisionEngine**: 6 archivos en `lib/el_paso/domain/decision_engine/` — `decision_engine.ex` (orquestador 4-capas), `scorer.ex` (keyword+regex scoring), `embedding_matcher.ex` (pgvector cosine similarity), `llm_classifier.ex` (modelo `[classifier]`), `decision_cache.ex` (ETS con TTL), `embedding_client.ex` (Ollama + caché ETS)
- [x] **Fase 3 — Sala Común**: `session_context.ex` (GenServer por sesión con shared_summary, knowledge_board, personality_stack), `session_supervisor.ex` (DynamicSupervisor), `context_builder.ex` (respeta token budget), `context_summarizer.ex` (extractive+abstractive), `token_counter.ex`
- [x] **Fase 4 — Compatibilidad Dual**: `anthropic/proxy.ex` — `from_anthropic` mapea modelo a personalidad, `map_anthropic_model` busca `find_by_model_name`. Pipeline unificado en `server.ex` para OpenAI y Anthropic con SessionContext integrado
- [x] **Fase 5 — Seguridad**: `secrets.ex` (AES-256-GCM para api_key en reposo), rate limiting en `/v1/chat/completions`, sanitización de logs anti-injection
- [x] **Fase 6 — Doctor genérico en Apero**: `Apero.Pkg` (behaviour + 7 implementaciones: apt, pacman, paru, brew, dnf, yum, zypper), `Apero.Doctor` (sistema de checks/fix configurable vía mapa)
- [x] **Fase 7 — ElPaso Doctor refactorizado**: `lib/el_paso/doctor.ex` delega en `Apero.Doctor`, 11 checks (OS, Elixir, pkg manager, PostgreSQL, pgvector, BD, migraciones, Ollama, embeddings, config, deps), `--fix` repara automáticamente
- [x] **Wrapper `localdocker`**: actualizado a `pgvector/pgvector:pg17`, nuevos comandos `pgvector` (instalar extensión sin borrar datos), `destroy`, `status` muestra si tiene pgvector
- [x] **Migración inicial**: `CREATE EXTENSION IF NOT EXISTS vector` añadido al `up/0` de `20240101000000_create_initial_tables.exs` para que `drop→create→migrate` no pierda pgvector
- [x] **README_ES.md**: sección "PostgreSQL + pgvector (OBLIGATORIO)" con opciones Docker + local, nombres de BD según entorno
- [x] **Apero integrado**: añadido como dependencia en `mix.exs`, `ElPaso.Application` ya no arranca `Zaguan.Engine.Supervisor` (lo hace Apero), `LlamaServerManager` usa `Apero.Runner`

### In Progress
- [ ] Esperar a que Zaguan compile (otro agente lo está arreglando) — ElPaso compila limpio, el error está solo en componentes UI de Zaguan que ElPaso no usa

### Blocked
- Zaguan tiene error de compilación en `Zaguan.UI.Components.*` (typespec `state/0` en Elixir 1.19.5). ElPaso compila bien porque usa la versión precompilada en `_build`. **NO tocar Zaguan.**

## Key Decisions
- **`nomic-embed-text` como default**: 274 MB, 768-dim, 100+ idiomas — mejor balance tamaño/calidad para routing. `bge-m3` (1.2 GB, 1024-dim) como upgrade opcional configurable
- **pgvector OBLIGATORIO**: sin él, el DecisionEngine solo puede usar capa 1 (keywords). La primera migración lo crea automáticamente
- **Doctor en Apero**: arquitectura de behaviour + config map para que cualquier app pueda reutilizarlo. ElPaso solo define 11 checks y delega
- **Zaguan NO se toca**: revertidos todos los cambios. El error de typespec es preexistente en Zaguan, no causado por esta sesión
- **Dimensiones de embedding dinámicas**: `embedding_client.ex` lee `embedding_dims` de config (768 o 1024), migración usa `:vector` sin size fijo

## Next Steps
1. Esperar a que Zaguan compile correctamente
2. Ejecutar `elpaso doctor --fix` para crear BD, migraciones, y verificar todo el entorno
3. Ejecutar `elpaso server start` para arrancar el proxy completo
4. Probar con curl ambos endpoints (OpenAI y Anthropic) con diferentes personalidades
5. Verificar que el DecisionEngine selecciona la personalidad correcta (ya no "gemma" siempre)
6. Probar el cambio de personalidad dentro de una misma sesión (Sala Común)

## Critical Context
- **BUG original "gemma siempre gana"**: `extract_keywords` solo generaba palabras sueltas ≥3 chars → triggers multi-palabra como "to english" nunca matcheaban → caía en default "general" → gemma. Fix: n-gramas + substring matching
- **Flujo de arranque**: `elpaso server start` → `Application.ensure_all_started` → `Bootstrap.run!()` (pgvector → Ollama → modelo embeddings) → `Plug.Cowboy.http`
- **pgvector en Docker**: NO necesita PostgreSQL en el host. `localdocker pgvector` instala la extensión dentro del contenedor sin borrar datos. Itera sobre `elpaso_dev`, `elpaso_test`, `elpaso_prod`
- **DecisionEngine 4-capas**: keyword (conf≥0.70) → embedding pgvector (conf≥0.55) → LLM classifier (modelo `[classifier]`) → default fallback. Resultados cacheados en ETS (TTL 5min)
- **Sala Común**: GenServer por sesión (`ElPaso.SessionRegistry` + `SessionSupervisor`). Al cambiar de personalidad, la nueva recibe `shared_summary` + `knowledge_board` + últimos 10 mensajes
- **`Apero.Helpers.question_with_options/2`** espera `[String.t()]`, NO tuplas. Devuelve la string seleccionada o nil. Bootstrap lo usa para selección dual de modelo

## File Operations
### Read
- (none new — audit completed in earlier session phases)

### Modified
- `priv/repo/migrations/20240101000000_create_initial_tables.exs` — convertido de `change/0` a `up/0`+`down/0`, añadido `execute "CREATE EXTENSION IF NOT EXISTS vector"` al inicio de `up`
- `priv/repo/migrations/20260505000002_decision_engine_v4.exs` — creado: añade `semantic_description`, `embedding vector`, `regex_patterns`, `min_confidence`, `cooldown_ms` a personalities
- `lib/el_paso/domain/router.ex` — delegado en DecisionEngine, extract_keywords con n-gramas
- `lib/el_paso/http/server.ex` — pipeline unificado + SessionContext + rate limiting + log sanitization
- `lib/el_paso/http/anthropic/proxy.ex` — `from_anthropic` mapea modelo a personalidad
- `lib/el_paso/domain/personality_manager.ex` — añadido `find_by_model_name/1`, funciones de embedding
- `lib/el_paso/application.ex` — añadido Registry, SessionSupervisor, EmbeddingClient, DecisionCache.init(); quitado Zaguan.Engine.Supervisor
- `lib/el_paso/cli.ex` — Bootstrap.run!() en server start, comando doctor con --fix
- `lib/el_paso/domain/llama_server_manager.ex` — `System.cmd` → `Apero.Runner.run`
- `mix.exs` — añadido `{:apero, path: "../apero"}`
- `README_ES.md` — requisitos sistema + pgvector + modelo embeddings
- `~/bin/localdocker` — wrapper actualizado con pgvector, comandos nuevos
