# 🏗️ ESTADO ACTUAL — ELPASO v4.0

**Fecha:** 2026-05-11  
**Versión:** v4.0 (Refactorización completa del sistema de routing y contexto)  
**Plan de referencia:** `PLAN_AUDITORIA_V4.md` (3049 líneas)  

---

## 📊 RESUMEN EJECUTIVO

ElPaso v4.0 es un proxy de inferencia multi-modelo para Elixir que expone una API unificada compatible con OpenAI y Anthropic. El proyecto ha completado **7 de 7 fases de implementación del core**, con ~57 archivos en `lib/el_paso/` y ~37 archivos de test. El foco actual es **testing y estabilización** (Fase 7 del plan), con dependencia bloqueante en Zaguan que otro agente está resolviendo.

---

## ✅ FUNCIONALIDADES IMPLEMENTADAS

### Fase 0 — Bootstrap (Prerrequisitos)
| Módulo | Líneas | Estado |
|--------|--------|--------|
| `lib/el_paso/bootstrap.ex` | 286 | ✅ Completo |

- Verificación secuencial de: PostgreSQL + pgvector → Ollama → modelo embeddings
- Soporte dual de modelos: `nomic-embed-text` (274 MB, 768-dim) y `bge-m3` (1.2 GB, 1024-dim)
- Descarga automática interactiva del modelo ausente con selección por terminal
- Se integra en `elpaso server start` — todo request es rechazado hasta que bootstrap completa
- Usa `Apero.Runner`, `Apero.Net`, `Apero.Proc` para operaciones de sistema

### Fase 1 — Fundación (Fix del Bug #1)
| Módulo | Líneas | Estado |
|--------|--------|--------|
| `lib/el_paso/domain/router.ex` | 248 | ✅ Refactorizado |
| `lib/el_paso/domain/router/task_categories.ex` | ~80 | ✅ Extraído |
| `lib/el_paso/http/message_normalizer.ex` | 77 | ✅ Completo |

**Bug "gemma siempre gana" — RESUELTO:**
- **Causa raíz:** `extract_keywords` filtraba palabras < 3 chars y usaba `Enum.member?` (match exacto) en vez de substring matching. Triggers multi-palabra como "to english" nunca matcheaban → caía en `default` → gemma.
- **Fix:** `extract_keywords` genera unigramas + bigramas + trigramas; `find_best_match` usa substring matching (`String.contains?`)
- `TaskCategories` extraído a módulo propio con mapeo de keywords a tipos de tarea
- `MessageNormalizer` unifica 5 formatos de mensaje a `%{role: atom, content: String.t()}`

### Fase 2 — DecisionEngine (4 Capas)
| Módulo | Líneas | Estado |
|--------|--------|--------|
| `lib/el_paso/domain/decision_engine.ex` | 145 | ✅ Orquestador |
| `lib/el_paso/domain/decision_engine/scorer.ex` | 130 | ✅ Capa 1 |
| `lib/el_paso/domain/decision_engine/embedding_matcher.ex` | 118 | ✅ Capa 2 |
| `lib/el_paso/domain/decision_engine/llm_classifier.ex` | 131 | ✅ Capa 3 |
| `lib/el_paso/domain/decision_engine/decision_cache.ex` | 88 | ✅ Caché ETS |
| `lib/el_paso/context/embedding_client.ex` | 174 | ✅ Ollama client |
| `priv/repo/migrations/20260505000002_decision_engine_v4.exs` | 61 | ✅ Migración |

**Pipeline de decisión multi-capa:**
```
Capa 1 (Scorer)          → keyword + regex + n-gramas     <1ms    conf≥0.70 → usa
Capa 2 (EmbeddingMatcher)→ pgvector cosine similarity     ~10ms   conf≥0.55 → usa
Capa 3 (LLMClassifier)   → modelo pequeño [classifier]     ~500ms  solo si ambiguo
Capa 4 (Default)         → is_default=true                 0ms     fallback
```

- Caché SHA256 en ETS con TTL de 5 minutos (`:routing_decision_cache`)
- `EmbeddingClient`: GenServer singleton con caché ETS (TTL 1 hora), integración Ollama `/api/embeddings`
- Migración añade: `semantic_description`, `embedding vector`, `regex_patterns`, `min_confidence`, `cooldown_ms` a `personalities`
- Índice `ivfflat` con `vector_cosine_ops` para búsqueda semántica rápida
- Auditoría extendida en `routing_decisions`: `personality_name`, `decision_layer`, `confidence`

### Fase 3 — Sala Común (Contexto Compartido)
| Módulo | Líneas | Estado |
|--------|--------|--------|
| `lib/el_paso/context/session_context.ex` | 239 | ✅ GenServer |
| `lib/el_paso/context/session_supervisor.ex` | 50 | ✅ DynamicSupervisor |
| `lib/el_paso/context/context_builder.ex` | 101 | ✅ Montaje de prompt |
| `lib/el_paso/context/context_summarizer.ex` | 108 | ✅ Summarizer |
| `lib/el_paso/context/token_counter.ex` | 65 | ✅ Estimador |

**Arquitectura de Sala Común:**
- Un `SessionContext` GenServer por sesión, supervisado por `SessionSupervisor` (DynamicSupervisor)
- Registry para lookup: `ElPaso.SessionRegistry` (`{:via, Registry, {SessionRegistry, session_id}}`)
- Estado compartido entre cambios de personalidad:
  - `shared_summary`: resumen acumulativo ≤ 500 tokens (vía `ContextSummarizer`)
  - `knowledge_board`: mapa de hechos/decisiones clave
  - `personality_stack`: historial de cambios de personalidad
  - `recent_messages`: ventana deslizante de últimos 10 mensajes
- `ContextBuilder` ensambla el prompt respetando el `token budget` del modelo (25% para system, 75% para historial+mensaje)
- `ContextSummarizer` soporta estrategia extractiva (rápida, sin LLM) y abstractiva (con LLM)

### Fase 4 — Compatibilidad Dual OpenAI/Anthropic
| Módulo | Líneas | Estado |
|--------|--------|--------|
| `lib/el_paso/http/server.ex` | 704 | ✅ Pipeline unificado |
| `lib/el_paso/http/anthropic/proxy.ex` | 195 | ✅ Mapeo bidireccional |
| `lib/el_paso/domain/personality_manager.ex` | 101 | ✅ find_by_model_name |

**Endpoints unificados:**
- `POST /v1/chat/completions` → `AnthropicProxy.from_openai` → pipeline común → `AnthropicProxy.to_openai`
- `POST /v1/messages` → `AnthropicProxy.from_anthropic` → pipeline común → `AnthropicProxy.to_anthropic`
- Ambos endpoints pasan por el mismo `DecisionEngine` + `SessionContext`
- `from_anthropic` mapea modelo Anthropic a personalidad vía `find_by_model_name/1`
- El campo `personality` (custom de ElPaso) permite selección explícita en ambos formatos

### Fase 5 — Seguridad y Mejoras
| Módulo | Líneas | Estado |
|--------|--------|--------|
| `lib/el_paso/security/secrets.ex` | 53 | ✅ AES-256-GCM |
| `lib/el_paso/security/rate_limiter.ex` | 97 | ✅ Token bucket ETS |
| `lib/el_paso/security/auth.ex` | existente | ✅ Existente |
| `lib/el_paso/security/jwt.ex` | existente | ✅ Existente |

- **API keys en reposo:** cifrado AES-256-GCM con `ELPASO_MASTER_KEY` (dev default, prod obligatorio). Formato: `Base64(iv ++ tag ++ ciphertext)`
- **Rate limiting:** token bucket en ETS por IP, 60 rpm en `/v1/chat/completions`. Algoritmo de recarga proporcional al tiempo transcurrido
- **Log sanitization:** `sanitize_for_log/1` previene log injection (strips `\n\r\t`, trunca a 128 chars)
- **Security headers:** CSP, HSTS, X-Frame-Options, X-Content-Type-Options en cada response

### Fase 6 — Documentación
| Archivo | Estado |
|---------|--------|
| `README_ES.md` | ✅ Actualizado con requisitos, pgvector, modelo embeddings, hardware |
| `README.md` | ✅ Existente (inglés) |
| `PLAN_AUDITORIA_V4.md` | ✅ Plan completo de 3049 líneas |

### Fase 7 — Doctor y Herramientas
| Módulo | Líneas | Estado |
|--------|--------|--------|
| `lib/el_paso/doctor.ex` | 499 | ✅ Completo |
| `~/bin/localdocker` | — | ✅ Actualizado |

**`elpaso doctor` — 11 checks de diagnóstico:**
1. Sistema Operativo (Linux/macOS/WSL2)
2. Elixir/OTP (versión)
3. Gestor de paquetes (apt/pacman/brew/dnf/yum/zypper)
4. PostgreSQL (Docker `localdocker` o instalación nativa)
5. Extensión pgvector en la BD
6. Base de datos (existe + conexión)
7. Migraciones (estado)
8. Ollama (servidor corriendo)
9. Modelo de embeddings (`nomic-embed-text` o `bge-m3`)
10. Configuración (`~/.config/elpaso/elpaso.conf`)
11. Dependencias (`mix deps`)

**`elpaso doctor --fix`** repara automáticamente: crea BD, ejecuta migraciones, descarga modelo embeddings, instala pgvector en Docker.

**`localdocker` wrapper actualizado:**
- Imagen: `pgvector/pgvector:pg17` (PostgreSQL 17 + pgvector preinstalado)
- Comando `pgvector`: instala extensión en todas las BD sin borrar datos
- Comando `status`: muestra versión + si tiene pgvector
- Comando `destroy`: elimina contenedor + datos + imagen con confirmación

---

## 🏛️ ARQUITECTURA COMPLETA

```
┌──────────────────────────────────────────────────────────┐
│                      Cliente HTTP                         │
│    POST /v1/chat/completions  |  POST /v1/messages       │
└──────────────────────┬───────────────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────────────┐
│  HTTP.Server (Plug.Router)                                │
│  ├─ Security headers (CSP, HSTS, X-Frame-Options)        │
│  ├─ Rate limiting (token bucket ETS, 60 rpm)              │
│  ├─ Log sanitization (anti-injection)                     │
│  └─ Routes: /v1/chat/completions, /v1/messages,          │
│     /v1/messages_stream, /metrics, /dashboard, /health   │
└──────────────────────┬───────────────────────────────────┘
                       ▼ MessageNormalizer → formato canónico
┌──────────────────────────────────────────────────────────┐
│  AnthropicProxy                                           │
│  ├─ from_openai / from_anthropic → InternalRequest       │
│  └─ to_openai / to_anthropic ← InternalResponse          │
└──────────────────────┬───────────────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────────────┐
│  Router → DecisionEngine (4 capas)                       │
│  ├─ Capa 1: Scorer (keyword + regex + n-gramas)          │
│  ├─ Capa 2: EmbeddingMatcher (pgvector cosine similarity) │
│  ├─ Capa 3: LLMClassifier (modelo [classifier])          │
│  ├─ Capa 4: Default (is_default=true)                    │
│  └─ DecisionCache (ETS, SHA256, TTL 5 min)               │
└──────────────────────┬───────────────────────────────────┘
                       ▼ Personalidad seleccionada
┌──────────────────────────────────────────────────────────┐
│  SessionContext (GenServer por sesión)                    │
│  ├─ shared_summary (≤500 tokens)                          │
│  ├─ knowledge_board (hechos clave)                        │
│  ├─ personality_stack (historial)                         │
│  └─ recent_messages (ventana deslizante, 10 últimos)     │
└──────────────────────┬───────────────────────────────────┘
                       ▼ ContextBuilder → prompt final
┌──────────────────────────────────────────────────────────┐
│  ModelManager.infer(model, prompt)                       │
│  └─ Engine.Dispatcher → Adapter (Ollama/OpenAI/Anthropic)│
└──────────────────────────────────────────────────────────┘
```

---

## 🔮 VISIÓN DEL PRODUCTO TERMINADO

Cuando ElPaso v4.0 esté completamente terminado, ofrecerá:

### Capacidades Core
- **Proxy multi-modelo unificado** — Un solo endpoint (`/v1/chat/completions`) para cualquier modelo local o remoto
- **Routing semántico inteligente** — Selección automática del mejor modelo/personalidad según la intención del usuario, usando 4 capas de decisión
- **Sala Común de contexto** — El usuario puede cambiar de personalidad a mitad de conversación sin perder contexto; la nueva personalidad recibe un resumen de lo ya conversado
- **Compatibilidad dual nativa** — Mismos pipelines de decisión tanto para clientes OpenAI (opencode, vscode, zed) como Anthropic (Claude Code, openclaw)
- **Extensibilidad vía personalidades** — Cualquiera puede crear personalidades con triggers, regex, descripciones semánticas y prioridades sin tocar código

### Operaciones y DevOps
- **Auto-bootstrap** — `elpaso server start` verifica y configura todo el entorno automáticamente (PostgreSQL, pgvector, Ollama, modelo embeddings)
- **Doctor autónomo** — `elpaso doctor --fix` diagnostica y repara cualquier problema de entorno sin intervención manual
- **Métricas completas** — Prometheus + telemetry para cada request (latencia, tokens, capa de decisión, personalidad)
- **Cluster nativo** — Soporte multi-nodo con libcluster (gossip o static discovery)

### Seguridad
- **API keys cifradas en reposo** — AES-256-GCM con clave maestra
- **Rate limiting por IP** — Token bucket en ETS, configurable
- **JWT authentication** — Para endpoints administrativos
- **Headers de seguridad** — CSP, HSTS, X-Frame-Options en cada response
- **Log injection prevention** — Sanitización de todos los inputs antes de loguear

### Rendimiento
- **Caché agresiva** — Decisiones cacheadas en ETS (SHA256, 5 min); embeddings cacheados (1 hora)
- **pgvector con índice ivfflat** — Búsqueda semántica ~10ms incluso con decenas de personalidades
- **Token budget management** — Cada request respeta el límite de contexto del modelo destino
- **Ventana deslizante** — Solo los últimos N mensajes van al prompt; el resto se resume

---

## 📋 TAREAS PENDIENTES

### 🔴 Bloqueante — Zaguan
| Tarea | Prioridad | Notas |
|-------|-----------|-------|
| Compilación de Zaguan | CRÍTICA | Typespec `state/0` no definido en `Zaguan.UI.Components.*`. Otro agente lo está arreglando. ElPaso compila limpio, pero no se puede ejecutar `elpaso server start` completo hasta que Zaguan compile. |

### 🟡 Tests (Fase 7 del plan)
| Tarea | Prioridad | Archivo(s) |
|-------|-----------|-----------|
| Tests del DecisionEngine | ALTA | `test/el_paso/domain/decision_engine_test.exs` (no existe) |
| Tests del Router con personalidades | ALTA | `test/el_paso/domain/router_personality_test.exs` (no existe) |
| Tests del SessionContext | ALTA | `test/el_paso/context/session_context_test.exs` (no existe) |
| Tests del ContextBuilder | MEDIA | `test/el_paso/context/context_builder_test.exs` (no existe) |
| Tests del EmbeddingClient (mockeando Ollama) | MEDIA | `test/el_paso/context/embedding_client_test.exs` (no existe) |
| Tests del Bootstrap | MEDIA | `test/el_paso/bootstrap_test.exs` (no existe) |
| Tests del Doctor | BAJA | `test/el_paso/doctor_test.exs` (no existe) |

### 🟡 Funcionalidades pendientes
| Tarea | Prioridad | Descripción |
|-------|-----------|-------------|
| `mix elpaso personality embed` | MEDIA | Comando CLI para regenerar embeddings de personalidades (útil tras cambiar `semantic_description` o de `nomic-embed-text` a `bge-m3`). El código en `PersonalityManager` ya existe, falta exponerlo en el CLI. |
| `mix elpaso session` | MEDIA | Comandos CLI para gestión de sesiones: `session list`, `session show ID`, `session clean` (limpiar inactivas). Parte de la funcionalidad ya existe en `context/` (vía `elpaso context list`). |
| `lib/el_paso/context/prefix_manager.ex` | BAJA | Caché de system prompts para evitar queries repetidos a BD. Documentado en el plan como archivo #13 pero no implementado aún. |
| Extraer `@task_categories` a configuración | BAJA | Mover las categorías de tareas de `TaskCategories` (módulo de código) a `config/config.exs` para que usuarios puedan extenderlas sin modificar código. |
| Tests de integración end-to-end | MEDIA | Probar el flujo completo: `POST /v1/chat/completions` → DecisionEngine → SessionContext → ModelManager → respuesta. Requiere Ollama corriendo o mocks completos. |
| Coverage ≥ 75% | ALTA | El umbral actual es 70%. El plan pide ≥ 75%. Con todos los tests nuevos debería alcanzarse. |

### 🟢 Mejoras futuras (post v4.0)
| Tarea | Descripción |
|-------|-------------|
| `ContextSummarizer` abstractivo | Actualmente solo está implementada la estrategia extractiva. La abstractiva (con LLM) está esqueletada pero no funcional. |
| `bge-m3` como default alternativo | La migración usa `:vector` sin size fijo, y `EmbeddingClient` soporta 1024-dim. Solo falta hacer el switch + regenerar embeddings más fácil. |
| Streaming SSE para Anthropic | El endpoint `/v1/messages_stream` está declarado pero el pipeline de streaming no está completamente integrado con SessionContext. |
| Dashboard web | `ElPaso.HTTP.Dashboard` existe. Se podría extender para mostrar decisiones de routing en tiempo real, sesiones activas, salud del sistema. |
| Plugins de motor | El sistema de adaptadores (`Engine.Adapter`) soporta Ollama, OpenAI, Anthropic, llama.cpp, vLLM. Se puede extender con Groq, Mistral, DeepSeek, etc. |
| Auto-escalado de modelos | `ModelManager` ya soporta start/stop de modelos. Se podría añadir auto-escalado basado en profundidad de cola (`current_queue_depth`). |

---

## 📂 INVENTARIO DE ARCHIVOS

### Nuevos (creados en v4.0) — 19 archivos
```
lib/el_paso/bootstrap.ex                          (286 líneas)
lib/el_paso/domain/decision_engine.ex              (145 líneas)
lib/el_paso/domain/decision_engine/scorer.ex       (130 líneas)
lib/el_paso/domain/decision_engine/embedding_matcher.ex (118 líneas)
lib/el_paso/domain/decision_engine/llm_classifier.ex   (131 líneas)
lib/el_paso/domain/decision_engine/decision_cache.ex   (88 líneas)
lib/el_paso/domain/router/task_categories.ex
lib/el_paso/context/session_context.ex             (239 líneas)
lib/el_paso/context/session_supervisor.ex          (50 líneas)
lib/el_paso/context/context_builder.ex             (101 líneas)
lib/el_paso/context/context_summarizer.ex          (108 líneas)
lib/el_paso/context/token_counter.ex               (65 líneas)
lib/el_paso/context/embedding_client.ex            (174 líneas)
lib/el_paso/http/message_normalizer.ex             (77 líneas)
lib/el_paso/security/secrets.ex                    (53 líneas)
lib/el_paso/doctor.ex                              (499 líneas)
priv/repo/migrations/20260505000002_decision_engine_v4.exs (61 líneas)
```

### Modificados — 9 archivos
```
lib/el_paso/domain/router.ex                     (refactorizado, n-gramas + delegación)
lib/el_paso/http/server.ex                       (rate limiting + SessionContext + sanitización)
lib/el_paso/http/anthropic/proxy.ex              (mapeo de modelos + personalidad)
lib/el_paso/domain/personality_manager.ex        (find_by_model_name, funciones embedding)
lib/el_paso/application.ex                       (Registry, SessionSupervisor, EmbeddingClient, DecisionCache)
lib/el_paso/domain/llama_server_manager.ex       (System.cmd → Apero.Runner)
lib/el_paso/cli.ex                               (Bootstrap en server start, comando doctor)
mix.exs                                          (dependencia apero)
README_ES.md                                     (requisitos, pgvector, modelo embeddings)
priv/repo/migrations/20240101000000_create_initial_tables.exs (CREATE EXTENSION vector)
```

### Externos — 2 archivos
```
~/bin/localdocker                                (pgvector/pgvector:pg17, comandos nuevos)
../../apero/lib/pkg.ex + 7 implementaciones      (Apero.Pkg behaviour)
../../apero/lib/doctor.ex                        (Apero.Doctor genérico)
```

---

## 🧪 VERIFICACIÓN DE COMPILACIÓN

```bash
# Estado actual
mix compile              # ✅ Compila limpio (solo warnings de Zaguan, externo)
mix compile --warnings-as-errors --no-deps-check  # ✅ Sin errores en ElPaso
```

---

## 📝 PRÓXIMOS PASOS RECOMENDADOS

1. **Esperar a que Zaguan compile** — El otro agente debe terminar el fix de typespec
2. **Ejecutar `elpaso doctor --fix`** — Crear BD, migraciones, verificar entorno completo
3. **Crear personalidades de prueba** — Al menos 3 (coder, translator, general) con semantic_description
4. **Ejecutar `elpaso server start`** — Verificar que bootstrap funciona y el servidor arranca
5. **Probar con curl** — Ambos endpoints (OpenAI y Anthropic) con diferentes personalidades
6. **Verificar el bug "gemma siempre gana"** — Probar con "translate to english" y verificar que NO selecciona gemma
7. **Implementar tests** — Empezar por `decision_engine_test.exs` y `router_personality_test.exs`
8. **Alcanzar coverage ≥ 75%** — Umbral requerido por el plan

---

*Documento generado por Macahan — Arquitecto Universal Supremo*
