# 🏗️ PLAN DE AUDITORÍA Y REFACTORIZACIÓN — ELPASO v4.0

**Fecha:** 2026-05-05  
**Versión:** v4.0 (Refactorización completa del sistema de routing y contexto)  
**Autor:** Macahan — Arquitecto Universal Supremo  
**Objetivo:** Documento único que cualquier agente puede usar para implementar TODAS las mejoras sin ambigüedad.

---

## 📋 ÍNDICE

0. [Prerrequisitos: Modelo de Embeddings y Especificaciones Hardware](#0-prerrequisitos-modelo-de-embeddings-y-especificaciones-hardware)
1. [BUG #1: "gemma" siempre gana — Root Cause y Fix inmediato](#1-bug-1-gemma-siempre-gana)
2. [Sistema Inteligente de Selección de Personalidad](#2-sistema-inteligente-de-selección-de-personalidad)
3. [Adaptación de la Creación de Personalidades al Nuevo Motor](#3-adaptación-de-la-creación-de-personalidades)
4. [Sala Común — Contexto Compartido entre Personalidades](#4-sala-común--contexto-compartido)
5. [Compatibilidad Dual: Endpoints OpenAI y Anthropic](#5-compatibilidad-dual-endpoints-openai-y-anthropic)
6. [Correcciones, Mejoras y Optimizaciones Adicionales](#6-correcciones-mejoras-y-optimizaciones)
7. [Requisitos de Documentación (README)](#7-requisitos-de-documentación-readme)

---

## 0. PRERREQUISITOS: MODELO DE EMBEDDINGS Y ESPECIFICACIONES HARDWARE

### 0.1 Modelo de Embeddings Seleccionado

**Modelo:** `nomic-embed-text` (v1.5)

| Característica | Valor |
|---|---|
| **Nombre en Ollama** | `nomic-embed-text` |
| **Tamaño de descarga** | **274 MB** |
| **Tamaño en RAM (quantized Q4_K_M)** | ~300 MB cargado en VRAM/RAM |
| **Dimensiones del embedding** | **768** (vector de 768 floats) |
| **Idiomas soportados** | **100+ idiomas**: español, inglés, francés, alemán, chino, japonés, árabe, ruso, portugués, italiano, etc. |
| **Rendimiento** | ~500 embeddings/segundo en CPU moderna, ~2000 en GPU |
| **Tooling** | Ollama (servidor local HTTP en `localhost:11434`) |
| **Endpoint de embeddings** | `POST http://localhost:11434/api/embeddings` |
| **Licencia** | Apache 2.0 |

**Por qué `nomic-embed-text` y no otros:**

| Modelo | Tamaño | Dims | Multilingual | Veredicto |
|---|---|---|---|---|
| `nomic-embed-text` | 274 MB | 768 | ✅ 100+ idiomas | **Elegido**: mejor balance tamaño/calidad/multilingüismo |
| `mxbai-embed-large` | 669 MB | 1024 | ⚠️ Principalmente EN | Descartado: 2.4x más grande, peor en español |
| `bge-m3` | 1.2 GB | 1024 | ✅ Excelente | Alternativa futura: demasiado grande como mínimo |
| `multilingual-e5-large` | 560 MB | 1024 | ✅ Muy bueno | Descartado: más grande, no disponible nativamente en Ollama |

**IMPORTANTE:** `nomic-embed-text` es el mínimo requerido. Si el usuario tiene hardware más potente, ElPaso debe permitir configurar `bge-m3` como alternativa para mayor calidad en embeddings multilingües (campo `embedding_model` en el archivo de configuración). La migración de un modelo a otro solo requiere regenerar los embeddings de las personalidades con `mix elpaso personality embed`.

### 0.2 Mecanismo de Arranque del Modelo de Embeddings

ElPaso DEBE usar Ollama como servidor de inferencia para embeddings. El flujo de arranque es:

```
elpaso server start
  │
  ├─ 1. Verificar que Ollama está corriendo (GET http://localhost:11434/api/tags)
  │     ├─ OK → continuar
  │     └─ FAIL → ERROR: "Ollama no está disponible. Instálalo: curl -fsSL https://ollama.com/install.sh | sh"
  │
  ├─ 2. Verificar que el modelo nomic-embed-text está disponible
  │     GET http://localhost:11434/api/tags → buscar "nomic-embed-text" en la lista
  │     ├─ Encontrado → continuar
  │     └─ No encontrado → DESCARGAR automáticamente:
  │           ollama pull nomic-embed-text
  │           (274 MB, ~2-5 minutos según conexión)
  │           Mostrar progreso: "⬇ Descargando modelo de embeddings nomic-embed-text (274 MB)..."
  │
  └─ 3. Verificar espacio en disco para pgvector (los embeddings ocupan ~3KB por personalidad)
        → Despreciable para la BD (< 1 MB incluso con 100 personalidades)
```

**Código de verificación en `application.ex` o en un módulo `ElPaso.Bootstrap`:**

```elixir
# FILE: lib/el_paso/bootstrap.ex
# NUEVO ARCHIVO

defmodule ElPaso.Bootstrap do
  @moduledoc """
  Verificaciones de arranque: disponibilidad de Ollama y modelo de embeddings.
  Se ejecuta antes de que el servidor HTTP acepte conexiones.
  """

  require Logger
  @ollama_url "http://localhost:11434"
  @embedding_model "nomic-embed-text"  # Configurable via app env

  @doc """
  Verifica que Ollama está corriendo y que el modelo de embeddings está disponible.
  Si no está, intenta descargarlo automáticamente.
  """
  def verify_embedding_model! do
    model = Application.get_env(:elpaso, :embedding_model, @embedding_model)

    # 1. Verificar Ollama
    case check_ollama_health() do
      :ok ->
        Logger.info("[Bootstrap] Ollama detectado en #{@ollama_url}")

        # 2. Verificar modelo de embeddings
        case model_available?(model) do
          true ->
            Logger.info("[Bootstrap] Modelo de embeddings '#{model}' disponible")

          false ->
            Logger.info("[Bootstrap] Modelo '#{model}' no encontrado. Descargando...")
            IO.puts("\n⬇  Descargando modelo de embeddings #{model} (274 MB)...")
            IO.puts("   Esto solo ocurre la primera vez. Tiempo estimado: 2-5 min.\n")

            case download_model(model) do
              :ok ->
                Logger.info("[Bootstrap] Modelo '#{model}' descargado correctamente")

              {:error, reason} ->
                raise """
                ❌ No se pudo descargar el modelo de embeddings '#{model}':
                   #{inspect(reason)}

                Descárgalo manualmente y vuelve a intentarlo:
                  ollama pull #{model}
                """
            end
        end

      {:error, reason} ->
        raise """
        ❌ Ollama no está disponible en #{@ollama_url}:
           #{inspect(reason)}

        ElPaso necesita Ollama para generar embeddings.
        Instálalo: curl -fsSL https://ollama.com/install.sh | sh
        O arranca el servicio si ya está instalado: ollama serve
        """
    end

    :ok
  end

  defp check_ollama_health do
    case Finch.build(:get, "#{@ollama_url}/api/tags")
         |> Finch.request(ElPaso.Finch, receive_timeout: 5_000) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: s}} -> {:error, "HTTP #{s}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp model_available?(model_name) do
    case Finch.build(:get, "#{@ollama_url}/api/tags")
         |> Finch.request(ElPaso.Finch, receive_timeout: 5_000) do
      {:ok, %{status: 200, body: body}} ->
        models = Jason.decode!(body) |> Map.get("models", [])
        Enum.any?(models, fn m -> m["name"] == "#{model_name}:latest" end)

      _ ->
        false
    end
  end

  defp download_model(model_name) do
    # Usar comando ollama pull (bloqueante, pero solo ocurre una vez)
    case System.cmd("ollama", ["pull", model_name], stderr_to_stdout: true, into: IO.stream(:stdio, :line)) do
      {_, 0} -> :ok
      {output, code} -> {:error, "Exit code #{code}: #{output}"}
    end
  end
end
```

### 0.3 Especificaciones Mínimas de Hardware

ElPaso v4.0 necesita ejecutar simultáneamente:

| Componente | RAM mínima | RAM recomendada | Notas |
|---|---|---|---|
| **PostgreSQL + pgvector** | 256 MB | 512 MB | La BD con embeddings ocupa poco |
| **Ollama (servidor base)** | 200 MB | 400 MB | Overhead del runtime |
| **nomic-embed-text (en RAM)** | 300 MB | 400 MB | Cargado en RAM/VRAM por Ollama |
| **1 modelo de inferencia pequeño** (ej: gemma-2b, qwen-0.5b) | 2 GB | 4 GB | El mínimo para que ElPaso sea funcional |
| **ElPaso (BEAM VM)** | 200 MB | 500 MB | Elixir/OTP + ETS caches |
| **Sistema operativo** | 500 MB | 1 GB | Linux headless |

### ✅ Requisitos mínimos totales

| Escenario | RAM total | Disco libre | GPU |
|---|---|---|---|
| **Mínimo funcional** (1 modelo pequeño + embeddings) | **6 GB** | 10 GB | No requerida (CPU) |
| **Recomendado** (2-3 modelos medianos) | **16 GB** | 30 GB | Recomendada (6+ GB VRAM) |
| **Producción** (varios modelos grandes) | **32 GB** | 100 GB | Necesaria (12+ GB VRAM) |

> ⚠️ **El cuello de botella NO es el modelo de embeddings** (solo 300 MB en RAM). El verdadero consumo viene de los modelos de inferencia que el usuario configure. ElPaso arranca con ~500 MB de RAM para sí mismo + Ollama + nomic-embed-text. El resto depende de los modelos.

> ℹ️ Si el usuario solo quiere usar APIs remotas (OpenAI, Anthropic) SIN modelos locales, los requisitos bajan drásticamente: **2 GB de RAM** serían suficientes (ElPaso + PostgreSQL + Ollama para embeddings). En este caso, nomic-embed-text sigue siendo necesario para el motor de decisiones semántico.

**Incluir en el README:**

```
## Requisitos del sistema

### Mínimos (modelos locales pequeños)
- RAM: 6 GB
- Almacenamiento: 10 GB libres
- SO: Linux (x86_64) o macOS (Apple Silicon)
- Ollama instalado (https://ollama.com)
- PostgreSQL 14+ con extensión pgvector

### Recomendados
- RAM: 16 GB
- GPU: 6+ GB VRAM (acelera inferencia local)
- Almacenamiento: 30 GB libres

### Uso solo con APIs remotas (sin modelos locales)
- RAM: 2 GB
- PostgreSQL 14+ con pgvector
- Ollama (solo para modelo de embeddings, descarga ~300 MB en RAM)
```

---

## 1. BUG #1: "gemma" SIEMPRE GANA

### 1.1 Diagnóstico

**Archivos involucrados:**
- `lib/el_paso/domain/router.ex` — `find_best_match/3`
- `lib/el_paso/http/server.ex` — `run_anthropic_pipeline/2` (líneas 441-528)
- `priv/repo/migrations/20260505000001_personality_driven_routing.exs` — seed data

**Cadena causal completa:**

```
Usuario envía: "hola, ¿cómo estás?"
  → run_anthropic_pipeline (server.ex:447): personality_hint = "auto"
  → Router.select_personality(messages) (router.ex:130)
  → extract_content → "hola cómo estás" (minúsculas)
  → extract_keywords → ["hola", "cómo", "estás"] (split por espacios, >= 3 chars)
  → detect_task_types → [] (ninguna keyword de task_category coincide con "hola cómo estás")
  → find_best_match(active_personalities, ["hola","cómo","estás"], [])
     PHASE 1 (keyword_matches): 
       - "coder": triggers = ["refactoriza","implementa",...]. ¿Alguna en ["hola","cómo","estás"]? NO
       - "architect": triggers = ["arquitectura","diseña",...]. NO
       - "legal-es": triggers = ["ley","BOE",...]. NO
       - "tutor": triggers = ["explica","explicar",...]. NO
       - "general": triggers = []. Enum.empty?([]) = true, NO
       → keyword_matches = []
     PHASE 2 (task_matches):
       - task_type_names = [] (no hay task_types detectados)
       - Para cada personalidad, ¿algún trigger_task_type in []? NO
       → task_matches = []
     PHASE 3 (default):
       - Enum.find(personalities, & &1.is_default) → "general" (is_default: true)
       → Devuelve "general" → model_id → "gemma"
```

**Problemas raíz identificados (3 bugs en cascada):**

1. **`tk in keywords` no funciona con triggers multi-palabra:** Los triggers como `"to english"`, `"pros and cons"`, `"por qué"` se comparan contra una lista de palabras individuales (keywords extraídas por split). Un trigger multi-palabra NUNCA está en la lista de palabras individuales.

2. **`extract_keywords` filtra palabras < 3 caracteres:** Esto elimina palabras clave críticas como "to", "in", "of", "el", "la", "de", "le", "un" — que son necesarias para detectar bigramas/trigramas significativos.

3. **Las personalidades sin `is_default` explícito dependen del fallback implícito:** En el caso de que haya varias personalidades sin `is_default: true`, `find_best_match` coge `hd(personalities)` (la primera activa ordenada por prioridad), que es impredecible.

### 1.2 Fix Inmediato — Corrección de la Extracción y Matching de Keywords

**Archivo a modificar:** `lib/el_paso/domain/router.ex`

#### 1.2.1 Reemplazar `extract_keywords/1`

```elixir
# FILE: lib/el_paso/domain/router.ex
# LÍNEAS 185-191 — REEMPLAZO COMPLETO

defp extract_keywords(content) do
  # 1. Normalizar: minúsculas
  normalized = String.downcase(content)

  # 2. Tokenizar en palabras individuales (sin filtrar por longitud)
  single_tokens =
    normalized
    |> String.split(~r/[\s,.;:!?¡¿"']+/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.uniq()

  # 3. Generar bigramas y trigramas para capturar frases clave
  bigrams = generate_ngrams(single_tokens, 2)
  trigrams = generate_ngrams(single_tokens, 3)

  # 4. Unir todo: palabras sueltas + bigramas + trigramas
  #    Prioridad: las palabras sueltas primero (más genéricas),
  #    luego los n-gramas (más específicos pero más lentos de match)
  single_tokens ++ bigrams ++ trigrams
end

# NUEVA función helper
defp generate_ngrams(tokens, n) do
  tokens
  |> Enum.chunk_every(n, 1, :discard)
  |> Enum.map(&Enum.join(&1, " "))
end
```

#### 1.2.2 Reemplazar `find_best_match/3` — Fase 1 (keyword matching)

El problema actual es que `tk in keywords` busca una match exacta del trigger en la lista de palabras. Con la nueva `extract_keywords`, los n-gramas ya están en la lista, así que los triggers multi-palabra funcionarán. Pero además, necesitamos hacer el matching más robusto: **substring matching contra el contenido completo** para cuando las palabras no se tokenizan exactamente igual.

```elixir
# FILE: lib/el_paso/domain/router.ex
# LÍNEAS 210-244 — REEMPLAZO COMPLETO de find_best_match/3

defp find_best_match(personalities, keywords, task_types) do
  task_type_names = Enum.map(task_types, & &1.type)

  # Fase 1: keyword matching mejorado
  keyword_matches =
    Enum.filter(personalities, fn p ->
      triggers = p.trigger_keywords || []
      not Enum.empty?(triggers) and
        Enum.any?(triggers, fn trigger ->
          # Buscar trigger como substring en los keywords extraídos
          # (soporta triggers multi-palabra gracias a los n-gramas)
          Enum.any?(keywords, fn kw -> String.contains?(kw, trigger) end)
        end)
    end)

  cond do
    not Enum.empty?(keyword_matches) ->
      best = return_highest_priority(keyword_matches)
      # Registrar qué trigger disparó para debugging
      trigger_found = Enum.find(best.trigger_keywords || [], fn tk ->
        Enum.any?(keywords, fn kw -> String.contains?(kw, tk) end)
      end)
      Map.put(best, :matched_with, "keyword:#{trigger_found}")

    # Fase 2: match por trigger_task_types (sin cambios)
    true ->
      task_matches =
        Enum.filter(personalities, fn p ->
          triggers = p.trigger_task_types || []
          not Enum.empty?(triggers) and
            Enum.any?(triggers, fn tt -> tt in task_type_names end)
        end)

      unless Enum.empty?(task_matches) do
        best = return_highest_priority(task_matches)
        Map.put(best, :matched_with, "task:#{hd(task_type_names)}")
      else
        # Fase 3: default
        default = Enum.find(personalities, & &1.is_default)
        if default, do: Map.put(default, :matched_with, "default"), else: hd(personalities)
      end
  end
end

defp return_highest_priority(matches) do
  matches
  |> Enum.max_by(&(&1.priority || 0), fn -> hd(matches) end)
end
```

#### 1.2.3 Registrar la razón del match en `build_result`

```elixir
# FILE: lib/el_paso/domain/router.ex
# LÍNEAS 251-272 — MODIFICAR build_result/3

defp build_result(personality, _keywords, task_types) do
  model = personality.model
  engine = personality.engine
  config = personality.config || %{}

  %{
    personality_name: personality.name,
    system_prompt: personality.system_prompt,
    model_name: model && model.name,
    model_id: personality.model_id,
    engine_id: personality.engine_id,
    engine_name: engine && engine.name,
    config: config,
    temperature: Map.get(config, "temperature", model && model.temperature),
    max_tokens: Map.get(config, "max_tokens", model && model.max_tokens),
    top_p: Map.get(config, "top_p", model && model.top_p),
    # MEJORADO: incluir el trigger exacto que causó el match
    decision_reason: Map.get(personality, :matched_with) || "#{personality.name} (priority: #{personality.priority})",
    matched_with: Map.get(personality, :matched_with, "default"),
    task_type: (task_types |> Enum.map(& &1.type) |> List.first()) || "unknown",
    score: personality.priority,
    timestamp: DateTime.utc_now()
  }
end
```

---

## 2. SISTEMA INTELIGENTE DE SELECCIÓN DE PERSONALIDAD

### 2.1 Diagnóstico del Sistema Actual

El sistema actual tiene **tres capas de decisión** (keyword → task_type → default) que son todas determinísticas y basadas en heurísticas manuales. Los problemas son:

| Problema | Impacto |
|----------|---------|
| Keywords manuales se quedan obsoletas | Mantenimiento insostenible |
| Sin comprensión semántica | "escribe un poema en Rust" → ¿es creative o code? |
| Sin aprendizaje | Cada request se evalúa desde cero, sin aprovechar decisiones pasadas |
| `detection_rules` del schema nunca se usan | Campo muerto en DB |
| Sin feedback loop | No se registra si la personalidad elegida fue buena o no |
| Los task_types están hardcodeados en el módulo | No extensible sin modificar código |

### 2.2 Arquitectura Propuesta — Motor de Decisión en 4 Capas

```
┌─────────────────────────────────────────────────────────────────────┐
│                  ELPASO DECISION ENGINE v4                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  REQUEST ──► ┌─────────────┐                                         │
│              │ Capa 1:      │ Determinista. Rápida (<1ms)            │
│              │ Keyword      │ Triggers explícitos + regex + n-gramas │
│              │ Matching     │ Si confianza > 0.8 → decisión final    │
│              └──────┬──────┘                                         │
│                     │ baja confianza / ambigüedad                     │
│                     ▼                                                │
│              ┌─────────────┐                                         │
│              │ Capa 2:      │ Semántica. (~5-50ms con pgvector)      │
│              │ Embedding    │ Cosine similarity contra personalidades │
│              │ Similarity   │ Si confianza > 0.7 → decisión final    │
│              └──────┬──────┘                                         │
│                     │ baja confianza                                 │
│                     ▼                                                │
│              ┌─────────────┐                                         │
│              │ Capa 3:      │ Si embedding también es ambiguo:       │
│              │ LLM          │ Preguntar a un modelo pequeño/barato   │
│              │ Classifier   │ "¿Qué personalidad usar?" (costoso)    │
│              └──────┬──────┘                                         │
│                     │                                                │
│                     ▼                                                │
│              ┌─────────────┐                                         │
│              │ Capa 4:      │ Fallback absoluto                      │
│              │ Default      │ Personalidad is_default=true           │
│              └─────────────┘                                         │
│                                                                     │
│  FEEDBACK ──► RoutingDecision se registra con scores y outcome       │
│               AutoTuner ajusta pesos y thresholds periódicamente     │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.3 Implementación Detallada

#### 2.3.1 Archivos Nuevos a Crear

| Archivo | Propósito |
|---------|-----------|
| `lib/el_paso/domain/decision_engine.ex` | Orquestador de las 4 capas |
| `lib/el_paso/domain/decision_engine/embedding_matcher.ex` | Capa 2: pgvector similarity |
| `lib/el_paso/domain/decision_engine/llm_classifier.ex` | Capa 3: clasificación por LLM |
| `lib/el_paso/domain/decision_engine/scorer.ex` | Cálculo de scores de confianza |

#### 2.3.2 Archivos a Modificar

| Archivo | Cambio |
|---------|--------|
| `lib/el_paso/domain/router.ex` | Delegar en `DecisionEngine` en vez de lógica inline |
| `lib/el_paso/http/server.ex` | Adaptar `run_anthropic_pipeline` al nuevo resultado |
| `lib/el_paso/domain/personality_manager.ex` | Añadir funciones para embedding cache |

#### 2.3.3 Nueva Migration

Archivo: `priv/repo/migrations/VERSION_decision_engine_v4.exs`

Añadir a la tabla `personalities`:
```elixir
alter table(:personalities) do
  # Descriptor semántico en texto libre (más rico que keywords)
  add :semantic_description, :text
  # Embedding precomputado (768-dim de nomic-embed-text)
  add :embedding, :vector, size: 768
  # Patrones regex compilables (ej: "\\b(def|fn|function)\\b")
  add :regex_patterns, {:array, :string}, default: []
  # Nivel mínimo de confianza para auto-activación (0.0-1.0)
  add :min_confidence, :float, default: 0.5
  # Cooldown entre activaciones (ms) para evitar oscilación
  add :cooldown_ms, :integer, default: 0
end

# Índice ivfflat para búsqueda de embeddings
execute """
CREATE INDEX IF NOT EXISTS idx_personalities_embedding
ON personalities USING ivfflat (embedding vector_cosine_ops) WITH (lists = 10);
"""
```

#### 2.3.4 `DecisionEngine` — Módulo Orquestador

```elixir
# FILE: lib/el_paso/domain/decision_engine.ex
# NUEVO ARCHIVO

defmodule ElPaso.Domain.DecisionEngine do
  @moduledoc """
  Motor de decisión multi-capa para selección de personalidad.

  Pipeline:
    1. Keyword/Regex matching (rápido, determinista)
    2. Embedding similarity (pgvector, semántico)
    3. LLM classification (modelo pequeño, alta precisión)
    4. Default fallback

  Cada capa devuelve una tupla {:ok, personality, confidence, layer} o
  {:undecided, candidates, reason} para pasar a la siguiente capa.
  """

  alias ElPaso.Domain.DecisionEngine.{EmbeddingMatcher, LLMClassifier, Scorer}
  alias ElPaso.Domain.PersonalityManager

  # Thresholds configurables via application env
  @keyword_confidence_threshold 0.80
  @embedding_confidence_threshold 0.65

  @doc """
  Selecciona la mejor personalidad para los mensajes dados.

  Devuelve:
    {:ok, personality_map, decision_metadata}
    {:error, reason}
  """
  @spec decide(list(map())) :: {:ok, map(), map()} | {:error, atom()}
  def decide(messages) do
    content = extract_full_content(messages)
    active = PersonalityManager.list_active()

    if active == [] do
      {:error, :no_active_personality}
    else
      result = do_decide(active, content)
      {:ok, result.personality, result.metadata}
    end
  end

  defp do_decide(personalities, content) do
    # Capa 1: Keyword + Regex matching
    case Scorer.keyword_score(personalities, content) do
      %{confidence: conf} = result when conf >= @keyword_confidence_threshold ->
        %{personality: result.personality, metadata: %{layer: :keyword, confidence: conf, matched_trigger: result.trigger}}

      _ ->
        # Capa 2: Embedding similarity
        case EmbeddingMatcher.match(personalities, content) do
          {:ok, result} when result.confidence >= @embedding_confidence_threshold ->
            %{personality: result.personality, metadata: %{layer: :embedding, confidence: result.confidence, top_matches: result.top_matches}}

          _ ->
            # Capa 3: LLM Classifier (solo si hay ambigüedad real)
            case LLMClassifier.classify(personalities, content) do
              {:ok, result} ->
                %{personality: result.personality, metadata: %{layer: :llm, confidence: result.confidence, reasoning: result.reasoning}}

              _ ->
                # Capa 4: Default
                default = Enum.find(personalities, & &1.is_default) || hd(personalities)
                %{personality: default, metadata: %{layer: :default, confidence: 1.0}}
            end
        end
    end
  end

  defp extract_full_content(messages) do
    messages
    |> Enum.map(fn
      %{"content" => c} -> c
      %{content: c} -> c
      _ -> ""
    end)
    |> Enum.join("\n")
  end
end
```

#### 2.3.5 `Scorer` — Capa 1: Keyword + Regex Scoring

```elixir
# FILE: lib/el_paso/domain/decision_engine/scorer.ex
# NUEVO ARCHIVO

defmodule ElPaso.Domain.DecisionEngine.Scorer do
  @moduledoc """
  Calcula scores de matching determinista para personalidades.

  Evalúa:
    - Keyword triggers (n-gram aware)
    - Regex patterns (nuevo campo regex_patterns)
    - Task type heuristics (mantenido como fallback rápido)
    - Prioridad y cooldown
  """

  defstruct [:personality, :confidence, :trigger, :all_scores]

  @doc """
  Evalúa todas las personalidades y devuelve la mejor match con su confianza.
  """
  def keyword_score(personalities, content) do
    normalized = String.downcase(content)
    keywords = tokenize_ngrams(normalized)

    scores =
      Enum.map(personalities, fn p ->
        score = calculate_personality_score(p, normalized, keywords)
        {p, score}
      end)

    best = Enum.max_by(scores, fn {_, s} -> s end, fn -> {hd(personalities), 0} end)

    {personality, score} = best
    max_possible = max_possible_score(personality)

    confidence = if max_possible > 0, do: score / max_possible, else: 0.0

    %__MODULE__{
      personality: personality,
      confidence: Float.round(confidence, 3),
      trigger: find_best_trigger(personality, normalized, keywords),
      all_scores: scores
    }
  end

  defp calculate_personality_score(personality, content, keywords) do
    kw_score = keyword_trigger_score(personality.trigger_keywords || [], keywords, content)
    regex_score = regex_trigger_score(personality.regex_patterns || [], content)
    task_score = task_type_score(personality.trigger_task_types || [], content)

    # Pesos: keywords 50%, regex 30%, task_type 20%
    kw_score * 0.5 + regex_score * 0.3 + task_score * 0.2
  end

  defp keyword_trigger_score(triggers, keywords, content) do
    return 0 if Enum.empty?(triggers)

    matched = Enum.count(triggers, fn trigger ->
      Enum.any?(keywords, fn kw -> String.contains?(kw, trigger) end) or
        String.contains?(content, trigger)
    end)

    # Score normalizado: cuántos triggers coinciden
    matched / length(triggers)
  end

  defp regex_trigger_score(patterns, content) do
    return 0 if Enum.empty?(patterns)

    matched = Enum.count(patterns, fn pattern ->
      case Regex.compile(pattern) do
        {:ok, regex} -> Regex.match?(regex, content)
        _ -> false
      end
    end)

    matched / length(patterns)
  end

  defp task_type_score(task_types, content) do
    return 0 if Enum.empty?(task_types)

    # Usar el mapa de @task_categories del Router (refactorizado a módulo compartido)
    detected = ElPaso.Domain.Router.TaskCategories.detect(content)

    matched = Enum.count(task_types, fn tt ->
      Enum.any?(detected, fn d -> d.type == tt end)
    end)

    if Enum.empty?(detected), do: 0, else: matched / length(task_types)
  end

  defp max_possible_score(_personality), do: 1.0

  defp tokenize_ngrams(content) do
    tokens = String.split(content, ~r/[\s,.;:!?¡¿"']+/, trim: true)
    unigrams = tokens
    bigrams = tokens |> Enum.chunk_every(2, 1, :discard) |> Enum.map(&Enum.join(&1, " "))
    trigrams = tokens |> Enum.chunk_every(3, 1, :discard) |> Enum.map(&Enum.join(&1, " "))
    unigrams ++ bigrams ++ trigrams
  end

  defp find_best_trigger(personality, content, keywords) do
    triggers = personality.trigger_keywords || []
    Enum.find(triggers, fn t ->
      Enum.any?(keywords, fn kw -> String.contains?(kw, t) end)
    end)
  end
end
```

#### 2.3.6 `EmbeddingMatcher` — Capa 2: Similitud Semántica

```elixir
# FILE: lib/el_paso/domain/decision_engine/embedding_matcher.ex
# NUEVO ARCHIVO

defmodule ElPaso.Domain.DecisionEngine.EmbeddingMatcher do
  @moduledoc """
  Capa 2 del DecisionEngine: matching por similitud semántica usando pgvector.

  Flujo:
    1. Generar embedding del prompt del usuario (vía API de embeddings local/remota)
    2. Comparar cosine similarity contra embeddings precomputados de cada personalidad
    3. Devolver la mejor match con score de confianza
  """

  alias ElPaso.Repo
  alias ElPaso.Models.Personality
  import Ecto.Query

  defstruct [:personality, :confidence, :top_matches]

  @doc """
  Busca la personalidad más cercana semánticamente al contenido.

  Usa cosine similarity via pgvector. Las personalidades deben tener su embedding
  precomputado (campo `embedding` con tipo `vector(768)`).
  """
  def match(personalities, content) do
    # 1. Generar embedding del contenido del usuario
    case generate_embedding(content) do
      {:ok, query_embedding} ->
        # 2. Obtener IDs de personalidades activas
        active_ids = Enum.map(personalities, & &1.id)
        embedding_str = Pgvector.encode(query_embedding)

        # 3. Query pgvector: cosine similarity contra embeddings precomputados
        results =
          from(p in Personality,
            where: p.id in ^active_ids and not is_nil(p.embedding),
            select: %{
              id: p.id,
              name: p.name,
              similarity: fragment("1 - (? <=> ?::vector)", p.embedding, type(^embedding_str, :string))
            },
            order_by: [desc: fragment("1 - (? <=> ?::vector)", p.embedding, type(^embedding_str, :string))],
            limit: 3
          )
          |> Repo.all()

        case results do
          [best | rest] ->
            personality = Enum.find(personalities, & &1.id == best.id)
            confidence = calculate_embedding_confidence(results)

            {:ok,
             %__MODULE__{
               personality: personality,
               confidence: confidence,
               top_matches: results
             }}

          [] ->
            {:error, :no_embeddings_available}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Embedding Generation ───────────────────────────────────────────

  defp generate_embedding(content) do
    # Usar el embedding_client configurado (OpenAI, Ollama con nomic-embed-text, etc.)
    # Por ahora: delegar a un GenServer que cachea y gestiona el cliente de embeddings
    ElPaso.Context.EmbeddingClient.embed(content)
  end

  defp calculate_embedding_confidence(results) do
    case results do
      [best | _] ->
        # Si el mejor es significativamente mejor que el segundo, alta confianza
        best_sim = best.similarity
        confidence = Float.round(best_sim, 3)
        confidence

      [] ->
        0.0
    end
  end
end
```

#### 2.3.7 `LLMClassifier` — Capa 3: Clasificación por LLM

```elixir
# FILE: lib/el_paso/domain/decision_engine/llm_classifier.ex
# NUEVO ARCHIVO

defmodule ElPaso.Domain.DecisionEngine.LLMClassifier do
  @moduledoc """
  Capa 3 del DecisionEngine: usar un modelo pequeño/rápido para decidir
  qué personalidad usar cuando las capas anteriores son ambiguas.

  Solo se invoca si:
    - Keyword matching dio confianza < threshold
    - Embedding similarity dio confianza < threshold
    - Hay al menos 2 personalidades candidatas viables
  """

  defstruct [:personality, :confidence, :reasoning]

  @classification_prompt """
  Eres un clasificador de intenciones. Tu tarea es decidir qué especialista
  debe atender la siguiente consulta del usuario.

  Personalidades disponibles:
  <%= for p <- @personalities do %>
  - <%= p.name %>: <%= p.description %>
  <% end %>

  Consulta del usuario:
  "<%= @content %>"

  Responde EXCLUSIVAMENTE con el nombre de la personalidad más adecuada.
  Si ninguna es claramente adecuada, responde "general".
  Solo el nombre, nada más.
  """

  @doc """
  Clasifica el contenido usando un modelo de lenguaje pequeño.

  Usa un modelo ligero/rápido configurado como `classifier` (ej: phi-3-mini, gemma-2b).
  """
  def classify(personalities, content) do
    # Building prompt
    descriptions =
      Enum.map(personalities, fn p ->
        %{name: p.name, description: p.description || p.name}
      end)

    prompt =
      EEx.eval_string(@classification_prompt,
        personalities: descriptions,
        content: content
      )

    messages = [%{role: "user", content: prompt}]

    # Usar el modelo clasificador (configurado como engine "classifier")
    case infer_classifier(messages) do
      {:ok, response} ->
        chosen_name = String.trim(response)
        chosen = Enum.find(personalities, &(&1.name == chosen_name))

        if chosen do
          {:ok,
           %__MODULE__{
             personality: chosen,
             confidence: 0.85,
             reasoning: "LLM classifier selected '#{chosen_name}'"
           }}
        else
          {:error, :llm_selected_unknown_personality}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp infer_classifier(messages) do
    # Buscar el modelo marcado como classifier (tag "classifier" en description)
    import Ecto.Query

    classifier_model =
      ElPaso.Repo.one(
        from(m in ElPaso.Models.Model,
          where: m.active == true and like(m.description, "%[classifier]%"),
          limit: 1
        )
      )

    if classifier_model do
      ElPaso.Domain.ModelManager.infer(classifier_model.name, %{messages: messages})
    else
      {:error, :no_classifier_model_configured}
    end
  end
end
```

#### 2.3.8 Extraer `TaskCategories` a módulo compartido

```elixir
# FILE: lib/el_paso/domain/router/task_categories.ex
# NUEVO ARCHIVO (extraído de router.ex)

defmodule ElPaso.Domain.Router.TaskCategories do
  @moduledoc """
  Categorías de tarea con keywords y pesos.
  Extraído del Router para ser usado por el DecisionEngine.

  Las categorías son configurables via application env, permitiendo
  que los usuarios añadan sus propias categorías sin modificar código.
  """

  # Las mismas @task_categories que estaban en router.ex
  # (líneas 23-118 del router.ex actual)
  @default_categories %{
    code: %{keywords: %{...}},
    reasoning: %{keywords: %{...}},
    # ... etc
  }

  def categories do
    Application.get_env(:elpaso, :task_categories, @default_categories)
  end

  def detect(content) do
    normalized = String.downcase(content)

    categories()
    |> Enum.map(fn {type, %{keywords: kw_map}} ->
      score = Enum.reduce(kw_map, 0, fn {keyword, weight}, acc ->
        if String.contains?(normalized, keyword), do: acc + weight, else: acc
      end)
      {type, score}
    end)
    |> Enum.filter(fn {_, s} -> s > 0 end)
    |> Enum.sort_by(fn {_, s} -> s end, :desc)
    |> Enum.map(fn {t, s} -> %{type: t, score: s} end)
  end
end
```

### 2.4 Integración con el Router Existente

```elixir
# FILE: lib/el_paso/domain/router.ex
# MODIFICAR select_personality/1 (líneas 130-145)

@spec select_personality(list()) :: {:ok, map()} | {:error, atom()}
def select_personality(messages) do
  case DecisionEngine.decide(messages) do
    {:ok, personality, metadata} ->
      result = build_result_from_decision(personality, metadata)
      # Registrar la decisión para auto-tuning
      record_decision(messages, result, metadata)
      {:ok, result}

    {:error, reason} ->
      {:error, reason}
  end
end

defp build_result_from_decision(personality, metadata) do
  model = personality.model
  engine = personality.engine
  config = personality.config || %{}

  %{
    personality_name: personality.name,
    system_prompt: personality.system_prompt,
    model_name: model && model.name,
    model_id: personality.model_id,
    engine_id: personality.engine_id,
    engine_name: engine && engine.name,
    config: config,
    temperature: Map.get(config, "temperature", model && model.temperature),
    max_tokens: Map.get(config, "max_tokens", model && model.max_tokens),
    top_p: Map.get(config, "top_p", model && model.top_p),
    decision_layer: metadata.layer,
    decision_confidence: metadata.confidence,
    decision_reason: "#{personality.name} via #{metadata.layer} (confidence: #{metadata.confidence})",
    task_type: metadata[:task_type] || "unknown",
    score: metadata.confidence,
    timestamp: DateTime.utc_now()
  }
end

defp record_decision(messages, result, metadata) do
  # Async: no bloquea la respuesta
  Task.start(fn ->
    ElPaso.Context.Storage.save_routing_decision(%{
      request_id: generate_request_id(),
      session_id: get_session_id(messages),
      model_id: result.model_id || "unknown",
      task_type: result.task_type,
      selected_model: result.model_name,
      scores: %{
        personality: result.personality_name,
        layer: metadata.layer,
        confidence: metadata.confidence
      },
      reason: result.decision_reason,
      decided_at: DateTime.utc_now()
    })
  end)
end
```

---

## 3. ADAPTACIÓN DE LA CREACIÓN DE PERSONALIDADES

### 3.1 Schema Actualizado

```elixir
# FILE: lib/el_paso/models/personality.ex
# REEMPLAZAR COMPLETO

defmodule ElPaso.Models.Personality do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "personalities" do
    field(:name, :string)
    field(:description, :string)
    field(:system_prompt, :string)
    field(:active, :boolean, default: true)

    # ── Routing triggers (usados por todas las capas) ──
    field(:trigger_keywords, {:array, :string}, default: [])
    field(:trigger_task_types, {:array, :string}, default: [])
    field(:regex_patterns, {:array, :string}, default: [])
    field(:detection_rules, :map, default: %{})

    # ── Nueva capa semántica ──
    field(:semantic_description, :string)
    field(:embedding, Pgvector.Ecto.Vector)  # tipo vector(768)

    # ── Routing config ──
    field(:priority, :integer, default: 0)
    field(:is_default, :boolean, default: false)
    field(:min_confidence, :float, default: 0.5)
    field(:cooldown_ms, :integer, default: 0)

    # ── Config overrides ──
    field(:config, :map, default: %{})

    # ── Relaciones ──
    belongs_to(:model, ElPaso.Models.Model)
    belongs_to(:engine, ElPaso.Models.Engine)

    timestamps(inserted_at: :created_at)
  end

  def changeset(personality, attrs) do
    personality
    |> cast(attrs, [
      :name, :description, :system_prompt, :active,
      :trigger_keywords, :trigger_task_types, :regex_patterns,
      :detection_rules, :semantic_description, :embedding,
      :priority, :is_default, :min_confidence, :cooldown_ms,
      :config, :model_id, :engine_id
    ])
    |> validate_required([:name, :system_prompt, :semantic_description])
    |> unique_constraint(:name)
    |> validate_default_uniqueness()
    |> maybe_generate_embedding()
  end

  # ── Validación de unicidad del default ──
  defp validate_default_uniqueness(changeset) do
    if get_change(changeset, :is_default) == true do
      unique_constraint(changeset, :is_default,
        name: :one_default_personality,
        message: "solo puede haber una personalidad por defecto"
      )
    else
      changeset
    end
  end

  # ── Generación automática de embedding al crear/actualizar ──
  defp maybe_generate_embedding(changeset) do
    sd = get_change(changeset, :semantic_description)
    if sd && !get_change(changeset, :embedding) do
      # Deferir a after_insert/after_update hook
      changeset
    else
      changeset
    end
  end
end
```

### 3.2 Generación Automática de Embeddings

```elixir
# FILE: lib/el_paso/domain/personality_manager.ex
# AÑADIR funciones de embedding

@doc """
Crea una personalidad y genera automáticamente su embedding semántico.
"""
def create_personality(attrs) do
  result =
    %Personality{}
    |> Personality.changeset(attrs)
    |> Repo.insert()

  with {:ok, personality} <- result do
    # Generar embedding asíncrono
    Task.start(fn -> generate_and_store_embedding(personality) end)
    {:ok, personality}
  end
end

@doc """
Regenera los embeddings para todas las personalidades activas.
Útil tras cambiar el modelo de embeddings o las descripciones semánticas.
"""
def regenerate_all_embeddings do
  list_active()
  |> Enum.each(fn p ->
    generate_and_store_embedding(p)
  end)
  :ok
end

defp generate_and_store_embedding(%Personality{} = personality) do
  text_to_embed = build_embedding_text(personality)

  case ElPaso.Context.EmbeddingClient.embed(text_to_embed) do
    {:ok, embedding} ->
      from(p in Personality, where: p.id == ^personality.id)
      |> Repo.update_all(set: [embedding: embedding])

    {:error, reason} ->
      Logger.warning("[PersonalityManager] No se pudo generar embedding para #{personality.name}: #{inspect(reason)}")
  end
end

defp build_embedding_text(%Personality{} = p) do
  # Combinar campos relevantes para capturar la semántica de la personalidad
  [
    p.name,
    p.description,
    p.semantic_description,
    Enum.join(p.trigger_keywords || [], " "),
    Enum.join(p.trigger_task_types || [], " ")
  ]
  |> Enum.reject(&is_nil/1)
  |> Enum.join(". ")
end
```

### 3.3 CLI Actualizado para Personalidades

```elixir
# FILE: lib/mix/tasks/elpaso/personality.ex
# MODIFICAR add_personality/1 (líneas 38-76)

defp add_personality(args) do
  name = get_opt(args, "name")
  system_prompt = get_opt(args, "system-prompt")
  model_name = get_opt(args, "model")
  engine_name = get_opt(args, "engine")
  semantic_description = get_opt(args, "semantic-description")

  if name && system_prompt && semantic_description do
    model = if model_name, do: Repo.get_by(ElPaso.Models.Model, name: model_name)
    engine = if engine_name, do: Repo.get_by(ElPaso.Models.Engine, name: engine_name)

    keywords = parse_list(get_opt(args, "keywords"))
    task_types = parse_list(get_opt(args, "task-types"))
    regex_patterns = parse_list(get_opt(args, "regex-patterns"))
    priority = parse_int(get_opt(args, "priority"), 0)
    is_default = "--default" in args
    min_confidence = parse_float(get_opt(args, "min-confidence"), 0.5)

    attrs = %{
      name: name,
      system_prompt: system_prompt,
      semantic_description: semantic_description,
      description: get_opt(args, "description") || semantic_description,
      model_id: model && model.id,
      engine_id: engine && engine.id,
      trigger_keywords: keywords,
      trigger_task_types: task_types,
      regex_patterns: regex_patterns,
      priority: priority,
      is_default: is_default,
      min_confidence: min_confidence,
    }

    case PersonalityManager.create_personality(attrs) do
      {:ok, p} ->
        Output.success("""
        Personalidad '#{p.name}' creada:
          Priority: #{p.priority}#{if p.is_default, do: " (default)"}
          Model: #{model_name || "—"}
          Engine: #{engine_name || "—"}
          Keywords: #{Enum.count(keywords)}
          Regex patterns: #{Enum.count(regex_patterns)}
          Min confidence: #{p.min_confidence}
          Embedding: se generará en background...
        """)

      {:error, changeset} ->
        errors = Enum.map(changeset.errors, fn {k, {msg, _}} -> "#{k}: #{msg}" end)
        Output.error("Error: #{Enum.join(errors, ", ")}")
    end
  else
    Output.error("""
    Argumentos obligatorios:
      --name=<nombre>
      --system-prompt=<prompt>
      --semantic-description=<descripción semántica para embeddings>
    """)
  end
end
```

---

## 4. SALA COMÚN — CONTEXTO COMPARTIDO ENTRE PERSONALIDADES

### 4.1 Diagnóstico

**Estado actual:** El contexto de sesión NO existe funcionalmente en el pipeline de inferencia. Hay schemas de BD (`sessions`, `messages`, `conversation_summaries`), pero el pipeline (`run_anthropic_pipeline` en `server.ex`) envía los mensajes directamente al modelo SIN persistencia de sesión, SIN preservación de contexto entre cambios de personalidad, y SIN compartición de conocimiento.

**Lo que se necesita ("Sala Común"):**
- Una sesión donde múltiples personalidades pueden intervenir
- Al cambiar de personalidad, la nueva recibe un resumen compacto de lo que la anterior hizo
- El historial completo se preserva en BD
- El cambio entre personalidades es ágil (no se reenvían 5000 tokens de historial cada vez)

### 4.2 Arquitectura de la Sala Común

```
┌─────────────────────────────────────────────────────────────────────┐
│                      SALA COMÚN (Session Context)                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────────────────────────────────────┐          │
│  │ SHARED KNOWLEDGE BOARD (ETS + PostgreSQL)             │          │
│  │                                                      │          │
│  │  • Último resumen de la sesión (≤ 500 tokens)        │          │
│  │  • Estado actual (qué se está haciendo)               │          │
│  │  • Decisiones tomadas y por qué                       │          │
│  │  • Archivos/recursos referenciados                    │          │
│  │  • Personality activa y stack de cambios              │          │
│  └──────────────────────────────────────────────────────┘          │
│                              │                                      │
│     ┌────────────────────────┼────────────────────────┐            │
│     ▼                        ▼                        ▼            │
│  ┌──────────┐          ┌──────────┐           ┌──────────┐        │
│  │ Coder    │          │ Architect│           │ General  │        │
│  │ (gemma)  │          │ (opus)   │           │ (gemma)  │        │
│  └──────────┘          └──────────┘           └──────────┘        │
│                                                                     │
│  Cada personalidad, al activarse:                                  │
│    1. Recibe el SUMMARY de la sesión (lo que se ha hecho)          │
│    2. Recibe los últimos N mensajes (ventana deslizante)            │
│    3. Añade su system_prompt específico                             │
│    4. Genera respuesta y actualiza el SHARED BOARD                  │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.3 Componentes Nuevos

| Archivo | Propósito |
|---------|-----------|
| `lib/el_paso/context/session_context.ex` | GenServer que gestiona el estado compartido de la sesión |
| `lib/el_paso/context/context_builder.ex` | Construye el prompt contextual para cada personalidad |
| `lib/el_paso/context/context_summarizer.ex` | Resume conversaciones en ≤ 500 tokens |
| `lib/el_paso/context/token_counter.ex` | Estima tokens (aproximación: chars/4) |

### 4.4 `SessionContext` — El Estado Compartido

```elixir
# FILE: lib/el_paso/context/session_context.ex
# NUEVO ARCHIVO

defmodule ElPaso.Context.SessionContext do
  @moduledoc """
  Gestiona el estado compartido de una sesión (la "Sala Común").

  Es un GenServer por sesión, supervisado por SessionSupervisor.
  Almacena en ETS (rápido) + PostgreSQL (durable).

  Estado:
    - session_id: identificador único de sesión
    - current_personality: nombre de la personalidad activa ahora
    - personality_stack: historial de cambios de personalidad
    - shared_summary: resumen acumulativo de TODO lo hecho (≤ 500 tokens)
    - recent_messages: últimos N mensajes (ventana deslizante)
    - knowledge_board: mapa de hechos/decisiones clave (clave → valor)
    - active_since: timestamp de cuándo se activó la personalidad actual
  """

  use GenServer
  require Logger

  # ── Client API ────────────────────────────────────────────────────

  def start_link(session_id: session_id) do
    GenServer.start_link(__MODULE__, %{session_id: session_id}, name: via(session_id))
  end

  def via(session_id), do: {:via, Registry, {ElPaso.SessionRegistry, session_id}}

  @doc "La personalidad activa notifica que va a procesar un mensaje."
  def activate(session_id, personality_name) do
    GenServer.call(via(session_id), {:activate, personality_name})
  end

  @doc "La personalidad termina y actualiza el estado compartido."
  def deactivate(session_id, personality_name, summary_delta) do
    GenServer.call(via(session_id), {:deactivate, personality_name, summary_delta})
  end

  @doc "Obtiene el contexto completo para una personalidad."
  def get_context(session_id, personality_name) do
    GenServer.call(via(session_id), {:get_context, personality_name})
  end

  @doc "Añade un hecho al knowledge board."
  def put_knowledge(session_id, key, value) do
    GenServer.cast(via(session_id), {:put_knowledge, key, value})
  end

  @doc "Registra un mensaje en el historial."
  def record_message(session_id, role, content, model_id) do
    GenServer.cast(via(session_id), {:record_message, role, content, model_id})
  end

  # ── Server Callbacks ──────────────────────────────────────────────

  @impl true
  def init(%{session_id: session_id}) do
    # Intentar recuperar estado previo de PostgreSQL
    initial_state = load_state(session_id) || fresh_state(session_id)

    {:ok, initial_state}
  end

  @impl true
  def handle_call({:activate, personality_name}, _from, state) do
    state = put_in(state.current_personality, personality_name)
    state = put_in(state.active_since, System.monotonic_time(:millisecond))

    # Registrar cambio de personalidad
    stack_entry = %{
      personality: personality_name,
      activated_at: DateTime.utc_now(),
      previous: state.current_personality
    }
    state = update_in(state.personality_stack, &[stack_entry | &1])

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:deactivate, personality_name, summary_delta}, _from, state) do
    # Actualizar el resumen compartido con lo que esta personalidad hizo
    new_summary = merge_summaries(state.shared_summary, summary_delta, personality_name)
    state = put_in(state.shared_summary, new_summary)

    # Persistir resumen
    persist_summary(state.session_id, new_summary)

    duration_ms = System.monotonic_time(:millisecond) - (state.active_since || 0)
    Logger.debug("[SessionContext] #{personality_name} desactivada tras #{duration_ms}ms")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get_context, personality_name}, _from, state) do
    context = build_context_for_personality(state, personality_name)
    {:reply, {:ok, context}, state}
  end

  @impl true
  def handle_cast({:put_knowledge, key, value}, state) do
    state = put_in(state.knowledge_board[key], value)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:record_message, role, content, model_id}, state) do
    message = %{
      role: role,
      content: content,
      model_id: model_id,
      timestamp: DateTime.utc_now()
    }
    state = update_in(state.recent_messages, fn msgs ->
      (msgs ++ [message]) |> Enum.take(-@max_recent_messages)
    end)

    # Persistir mensaje en BD (async)
    Task.start(fn ->
      ElPaso.Context.Storage.create_message(%{
        session_id: state.session_id,
        role: role,
        content: content,
        model_id: model_id
      })
    end)

    {:noreply, state}
  end

  # ── Context Building ──────────────────────────────────────────────

  @max_recent_messages 10

  defp build_context_for_personality(state, personality_name) do
    # Construir el contexto que se enviará al modelo de la personalidad
    personality = ElPaso.Domain.PersonalityManager.get_personality(personality_name)

    %{
      # System prompt específico de la personalidad
      system_prompt: personality && personality.system_prompt,

      # Resumen de todo lo hecho en la sesión hasta ahora
      session_summary: state.shared_summary,

      # Knowledge board: hechos y decisiones clave
      knowledge_board: state.knowledge_board,

      # Historial de cambios de personalidad (para contexto)
      personality_switch_history: format_switch_history(state.personality_stack),

      # Últimos mensajes (ventana deslizante)
      recent_context: state.recent_messages,

      # Mensajes de sistema adicionales
      system_context: build_system_context(state, personality_name)
    }
  end

  defp build_system_context(state, personality_name) do
    lines = [
      "[ElPaso Session Context]",
      "Estás participando en una sesión multi-especialista.",
      "Personalidad actual: #{personality_name}",
    ]

    if state.shared_summary && state.shared_summary != "" do
      lines = lines ++ [
        "",
        "--- RESUMEN DE LA SESIÓN (lo que se ha hecho hasta ahora) ---",
        state.shared_summary,
        "--- FIN DEL RESUMEN ---"
      ]
    end

    if map_size(state.knowledge_board) > 0 do
      kb_lines = Enum.map(state.knowledge_board, fn {k, v} -> "  • #{k}: #{v}" end)
      lines = lines ++ ["", "--- INFORMACIÓN COMPARTIDA ---" | kb_lines]
    end

    Enum.join(lines, "\n")
  end

  defp format_switch_history(stack) do
    stack
    |> Enum.take(5)
    |> Enum.map(fn entry ->
      "#{entry.personality} (desde #{Calendar.strftime(entry.activated_at, "%H:%M:%S")})"
    end)
    |> Enum.join(" → ")
  end

  # ── Summary Merging ───────────────────────────────────────────────

  defp merge_summaries(current, delta, personality_name) do
    prefix = "[#{personality_name}] #{delta}"

    if current && current != "" do
      combined = "#{current}\n#{prefix}"
      # Si el resumen es muy largo, recomprimirlo
      if String.length(combined) > 2000 do
        ElPaso.Context.ContextSummarizer.compress(combined)
      else
        combined
      end
    else
      prefix
    end
  end

  defp persist_summary(session_id, summary) do
    ElPaso.Context.Storage.create_summary(%{
      session_id: session_id,
      summary: summary,
      summary_tokens: estimate_tokens(summary),
      window_start: DateTime.utc_now() |> DateTime.add(-3600),
      window_end: DateTime.utc_now()
    })
  end

  defp estimate_tokens(text), do: div(String.length(text || ""), 4)

  # ── Persistence Helpers ───────────────────────────────────────────

  defp fresh_state(session_id) do
    %{
      session_id: session_id,
      current_personality: nil,
      personality_stack: [],
      shared_summary: "",
      recent_messages: [],
      knowledge_board: %{},
      active_since: nil
    }
  end

  defp load_state(session_id) do
    # Recuperar el último resumen de PostgreSQL
    case ElPaso.Context.Storage.get_latest_summary(session_id) do
      nil -> nil
      summary ->
        %{
          session_id: session_id,
          current_personality: nil,
          personality_stack: [],
          shared_summary: summary.summary || "",
          recent_messages: [],
          knowledge_board: %{},
          active_since: nil
        }
    end
  end
end
```

### 4.5 `ContextBuilder` — Construcción del Prompt Final

```elixir
# FILE: lib/el_paso/context/context_builder.ex
# NUEVO ARCHIVO

defmodule ElPaso.Context.ContextBuilder do
  @moduledoc """
  Construye el prompt completo que se enviará al modelo, combinando:
    1. System prompt de la personalidad
    2. Contexto de sesión compartido (Sala Común)
    3. Ventana deslizante de mensajes recientes
    4. Mensaje actual del usuario

  Respeta el límite de tokens del modelo destino.
  """

  @default_max_tokens 4096
  @system_overhead_ratio 0.25  # 25% del contexto para system prompt

  @doc """
  Construye la lista de mensajes para enviar al modelo.

  Argumentos:
    - context: mapa devuelto por SessionContext.get_context/2
    - user_message: el mensaje actual del usuario
    - model_max_tokens: límite de tokens del modelo destino

  Devuelve:
    Lista de mensajes [{role, content}] lista para enviar al engine.
  """
  def build(context, user_message, model_max_tokens \\ @default_max_tokens) do
    system_budget = trunc(model_max_tokens * @system_overhead_ratio)
    history_budget = model_max_tokens - system_budget - estimate_tokens(user_message)

    # 1. System prompt base de la personalidad
    system_content = context.system_prompt || ""

    # 2. Añadir contexto de sesión compartido
    session_context = build_session_context_block(context)

    # 3. Combinar y truncar al budget
    full_system = truncate_to_token_budget(system_content <> "\n\n" <> session_context, system_budget)

    # 4. Ventana deslizante de historial reciente
    history = build_history_block(context.recent_context, history_budget)

    # 5. Construir lista final
    messages = [%{role: "system", content: full_system}]
    messages = messages ++ history
    messages = messages ++ [%{role: "user", content: user_message}]

    messages
  end

  defp build_session_context_block(context) do
    parts = []

    parts = if context.session_summary && context.session_summary != "" do
      parts ++ ["[CONTEXTO DE SESIÓN]\n#{context.session_summary}"]
    else
      parts
    end

    parts = if context.personality_switch_history && context.personality_switch_history != "" do
      parts ++ ["[HISTORIAL DE ESPECIALISTAS]\nHan intervenido: #{context.personality_switch_history}"]
    else
      parts
    end

    parts = if map_size(context.knowledge_board) > 0 do
      kb = Enum.map(context.knowledge_board, fn {k, v} -> "- #{k}: #{v}" end)
      parts ++ ["[INFORMACIÓN COMPARTIDA]\n#{Enum.join(kb, "\n")}"]
    else
      parts
    end

    Enum.join(parts, "\n\n")
  end

  defp build_history_block(recent_messages, budget) do
    recent_messages
    |> Enum.reverse()
    |> Enum.reduce({[], budget}, fn msg, {acc, remaining} ->
      tokens = estimate_tokens(msg.content)
      if tokens <= remaining do
        {[msg | acc], remaining - tokens}
      else
        {acc, 0}
      end
    end)
    |> elem(0)
    |> Enum.map(fn m -> %{role: m.role, content: m.content} end)
  end

  defp truncate_to_token_budget(text, budget) do
    if estimate_tokens(text) <= budget do
      text
    else
      # Truncar al budget, intentando mantener frases completas
      text
      |> String.slice(0, budget * 4)
      |> String.trim()
      |> Kernel.<>("\n[...contexto truncado por límite de tokens...]")
    end
  end

  defp estimate_tokens(text), do: div(String.length(text || ""), 4)
end
```

### 4.6 `ContextSummarizer` — Compresión de Contexto

```elixir
# FILE: lib/el_paso/context/context_summarizer.ex
# NUEVO ARCHIVO

defmodule ElPaso.Context.ContextSummarizer do
  @moduledoc """
  Resume texto de contexto a un formato compacto (≤ 500 tokens).

  Dos estrategias:
    1. Extractive: seleccionar frases clave (rápido, sin LLM)
    2. Abstractive: usar modelo pequeño para generar resumen (preciso, con LLM)
  """

  @max_summary_tokens 500

  @doc """
  Resume una conversación o bloque de texto largo a ≤ 500 tokens.
  """
  def summarize(text, strategy \\ :extractive)

  def summarize(text, :extractive) do
    # Estrategia extractiva simple: primeras y últimas frases + frases con keywords
    sentences = String.split(text, ~r/(?<=[.!?])\s+/)
    n = length(sentences)

    cond do
      n <= 5 ->
        text  # Ya es corto, no resumir

      n <= 15 ->
        # Tomar primeras 3 y últimas 2
        (Enum.take(sentences, 3) ++ Enum.take(sentences, -2))
        |> Enum.join(" ")

      true ->
        # Tomar primeras 3, últimas 2, y frases con keywords importantes
        important = Enum.filter(sentences, fn s ->
          String.match?(String.downcase(s), ~r/decid|implement|crear|error|fix|cambio|resultado/)
        end)
        (Enum.take(sentences, 3) ++ important ++ Enum.take(sentences, -2))
        |> Enum.uniq()
        |> Enum.take(10)
        |> Enum.join(" ")
    end
    |> String.slice(0, @max_summary_tokens * 4)
  end

  def summarize(text, :abstractive) do
    # Usar el modelo clasificador para generar un resumen
    prompt = """
    Resume el siguiente texto en 3-5 frases concisas, capturando solo la información
    más relevante para que otro especialista pueda continuar el trabajo. Máximo 500 tokens.

    Texto a resumir:
    #{text}
    """

    case ElPaso.Domain.DecisionEngine.LLMClassifier.infer_classifier([%{role: "user", content: prompt}]) do
      {:ok, response} -> String.trim(response.content)
      {:error, _} -> summarize(text, :extractive)  # Fallback a extractivo
    end
  end

  @doc """
  Comprime un resumen existente para que quepa en el presupuesto de tokens.
  """
  def compress(text, max_tokens \\ @max_summary_tokens) do
    if estimate_tokens(text) <= max_tokens do
      text
    else
      summarize(text, :extractive)
    end
  end

  defp estimate_tokens(text), do: div(String.length(text || ""), 4)
end
```

### 4.7 `TokenCounter` — Estimación de Tokens

```elixir
# FILE: lib/el_paso/context/token_counter.ex
# NUEVO ARCHIVO

defmodule ElPaso.Context.TokenCounter do
  @moduledoc """
  Estimador de tokens para controlar el presupuesto de contexto.

  Usa heurística chars/4 como aproximación rápida.
  Futuro: integración con tiktoken o el tokenizer del modelo.
  """

  @chars_per_token 4.0

  @doc "Estima el número de tokens en un texto."
  def count(text) when is_binary(text) do
    (String.length(text) / @chars_per_token) |> ceil()
  end

  @doc "Estima tokens de una lista de mensajes."
  def count_messages(messages) when is_list(messages) do
    Enum.reduce(messages, 0, fn msg, acc ->
      content = Map.get(msg, :content) || Map.get(msg, "content") || ""
      acc + count(content)
    end)
  end

  @doc "Verifica si los mensajes caben en el budget de tokens."
  def fits_in_budget?(messages, max_tokens) do
    count_messages(messages) <= max_tokens
  end
end
```

### 4.8 Session Supervisor

```elixir
# FILE: lib/el_paso/context/session_supervisor.ex
# NUEVO ARCHIVO

defmodule ElPaso.Context.SessionSupervisor do
  @moduledoc """
  DynamicSupervisor para SessionContext GenServers.

  Cada sesión tiene su propio GenServer que mantiene el estado compartido.
  Se crean bajo demanda y se terminan tras inactividad.
  """

  use DynamicSupervisor

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def ensure_session(session_id) do
    case Registry.lookup(ElPaso.SessionRegistry, session_id) do
      [{_pid, _}] ->
        :ok  # Ya existe

      [] ->
        # Crear nuevo SessionContext
        DynamicSupervisor.start_child(__MODULE__, %{
          id: ElPaso.Context.SessionContext,
          start: {ElPaso.Context.SessionContext, :start_link, [[session_id: session_id]]},
          restart: :temporary
        })
    end
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
```

### 4.9 Integración en el Pipeline HTTP

```elixir
# FILE: lib/el_paso/http/server.ex
# MODIFICAR run_anthropic_pipeline/2 (líneas 441-528)

defp run_anthropic_pipeline(internal_req, conn) do
  personality_hint = Map.get(internal_req, :personality_hint) ||
                     internal_req.model_hint || "auto"

  # ── Obtener o crear session_id ──
  session_id = Map.get(internal_req, :session_id) || generate_session_id()
  ElPaso.Context.SessionSupervisor.ensure_session(session_id)

  # ── Resolver personalidad ──
  {model_name, system_prompt, config_overrides, personality_name} =
    resolve_personality(personality_hint, internal_req.messages)

  # ── Activar personalidad en la Sala Común ──
  if personality_name do
    ElPaso.Context.SessionContext.activate(session_id, personality_name)

    # Obtener contexto enriquecido de la Sala Común
    {:ok, session_context} = ElPaso.Context.SessionContext.get_context(session_id, personality_name)

    # Construir prompt completo con contexto compartido
    user_message = extract_last_user_message(internal_req.messages)
    enriched_messages = ElPaso.Context.ContextBuilder.build(
      session_context,
      user_message,
      config_overrides["max_tokens"] || 4096
    )
  else
    enriched_messages = internal_req.messages
  end

  # ── Ejecutar inferencia ──
  # ... (misma lógica de fallback y ejecución que antes, pero con enriched_messages)

  # ── Tras la respuesta, actualizar Sala Común ──
  # (esto se hace en el caller, después de obtener la respuesta)
end
```

### 4.10 Registry para Sesiones

```elixir
# Añadir en application.ex, en la lista de children:
{Registry, keys: :unique, name: ElPaso.SessionRegistry},
ElPaso.Context.SessionSupervisor,
```

---

## 5. COMPATIBILIDAD DUAL: ENDPOINTS OPENAI Y ANTHROPIC

### 5.1 Diagnóstico de la Situación Actual

ElPaso expone **dos tipos de endpoints** en su servidor HTTP:

| Endpoint | Formato | Usado por | Pipeline |
|---|---|---|---|
| `POST /v1/chat/completions` | **OpenAI** | opencode, vscode, zed, apps genéricas | `run_anthropic_pipeline` (nombre legacy, ya procesa ambos) |
| `POST /v1/messages` | **Anthropic** | Claude Code, openclaw | `run_anthropic_pipeline` |
| `POST /v1/messages_stream` | **Anthropic SSE** | Claude Code (streaming) | `run_anthropic_stream` |

**Problema detectado:** El pipeline `run_anthropic_pipeline` solo usa el **Router de personalidades** cuando el endpoint es `/v1/chat/completions`. Para `/v1/messages` (Anthropic), el código en `server.ex`:

```elixir
# server.ex:91-126 — Endpoint Anthropic
post "/v1/messages" do
  # ...
  with internal_req <- ElPaso.HTTP.AnthropicProxy.from_anthropic(params),
       {:ok, response} <- run_anthropic_pipeline(internal_req, conn) do
  # ...
```

Aquí `from_anthropic` mapea el campo `model` a `model_hint` = `"auto"` (línea 129 del proxy: `map_anthropic_model/1` siempre devuelve `"auto"`). Luego en `run_anthropic_pipeline` (línea 442-443):

```elixir
personality_hint = Map.get(internal_req, :personality_hint) ||
                   internal_req.model_hint || "auto"
```

El campo `personality_hint` NO se setea desde el endpoint Anthropic (`from_anthropic` no lo asigna). Así que se usa `model_hint` → `"auto"` → sí pasa por el Router correctamente.

**PERO** hay un problema más sutil: el campo `personality` en el request Anthropic no tiene equivalente directo. Los clientes Anthropic envían `model` (que es el modelo concreto, no la personalidad). Esto significa que:

1. Si un cliente Anthropic envía `"model": "claude-sonnet"`, ElPaso debería mapear esto a una personalidad que use ese modelo, pero actualmente `map_anthropic_model/1` IGNORA el modelo y devuelve `"auto"` siempre.
2. El resultado es que el routing funciona (usa auto-detección), pero **pierde la pista explícita del modelo** que el cliente solicitó.

### 5.2 Solución: Pipeline Unificado con Resolución de Personalidad

El objetivo es que **AMBOS tipos de endpoint** pasen por el mismo `DecisionEngine`, y que tanto OpenAI como Anthropic puedan:
- **Opción A (explícita):** Indicar `personality: "coder"` o `model: "claude-sonnet"` → usar directamente
- **Opción B (auto):** No indicar nada → `DecisionEngine` elige la mejor personalidad
- **Opción C (híbrida):** Indicar `model: "claude-sonnet"` → filtrar personalidades que usen ese modelo, luego auto-detectar entre ellas

#### 5.2.1 Modificar `AnthropicProxy.from_anthropic/1`

```elixir
# FILE: lib/el_paso/http/anthropic/proxy.ex
# MODIFICAR from_anthropic/1 (líneas 26-38) y map_anthropic_model/1 (línea 127-129)

def from_anthropic(anthropic_params) when is_map(anthropic_params) do
  messages = Map.get(anthropic_params, "messages", [])
  system = Map.get(anthropic_params, "system")

  # NUEVO: preservar el modelo solicitado y mapearlo
  requested_model = Map.get(anthropic_params, "model")
  personality = Map.get(anthropic_params, "personality")  # Campo custom de ElPaso

  %InternalRequest{
    messages: messages,
    system_override: system,
    # El modelo Anthropic se mapea a modelo interno o se deja como hint
    model_hint: map_anthropic_model(requested_model),
    # Si el cliente Anthropic envía "personality" (campo custom), se respeta
    personality_hint: personality,
    max_tokens: Map.get(anthropic_params, "max_tokens"),
    temperature: Map.get(anthropic_params, "temperature"),
    stream: Map.get(anthropic_params, "stream", false)
  }
end

# NUEVO: mapear modelos Anthropic a modelos internos conocidos
defp map_anthropic_model(nil), do: "auto"
defp map_anthropic_model(""), do: "auto"
defp map_anthropic_model("auto"), do: "auto"

defp map_anthropic_model(model_name) do
  # Si el modelo Anthropic tiene un equivalente configurado en ElPaso, usarlo
  # Si no, devolver "auto" para que el DecisionEngine decida
  case ElPaso.Domain.ModelManager.get_model(model_name) do
    nil ->
      # Buscar si hay alguna personalidad asociada a este nombre de modelo
      case ElPaso.Domain.PersonalityManager.find_by_model_name(model_name) do
        nil -> "auto"
        personality -> personality.name
      end

    _model ->
      # El modelo existe directamente → usar "auto" para routing
      "auto"
  end
end
```

#### 5.2.2 Unificar `run_anthropic_pipeline` para Ambos Formatos

El pipeline actual en `server.ex` ya es mayormente unificado. Los cambios necesarios son:

```elixir
# FILE: lib/el_paso/http/server.ex
# MODIFICACIONES PUNTUALES en run_anthropic_pipeline/2

defp run_anthropic_pipeline(internal_req, conn) do
  # 1. Resolver personalidad (misma lógica para OpenAI y Anthropic)
  personality_hint = Map.get(internal_req, :personality_hint) ||
                     internal_req.model_hint || "auto"

  # 2. Obtener o crear sesión
  session_id = Map.get(internal_req, :session_id) || generate_session_id()

  # 3. Resolver personalidad → modelo
  {model_name, system_prompt, config_overrides, personality_name} =
    resolve_personality(personality_hint, internal_req.messages)

  # ... (resto igual: construir mensajes, ejecutar inferencia)

  # NOTA: La respuesta se formatea diferente según el endpoint:
  #   - /v1/chat/completions → AnthropicProxy.to_openai(response)
  #   - /v1/messages         → AnthropicProxy.to_anthropic(response)
  # Pero el pipeline INTERNO es el mismo.
end
```

#### 5.2.3 `PersonalityManager.find_by_model_name/1` — Nueva función

```elixir
# FILE: lib/el_paso/domain/personality_manager.ex
# AÑADIR

@doc """
Busca una personalidad que use un modelo concreto (por nombre de modelo).
Útil cuando un cliente Anthropic solicita un modelo específico.
"""
def find_by_model_name(model_name) do
  import Ecto.Query

  Personality
  |> join(:inner, [p], m in assoc(p, :model))
  |> where([p, m], m.name == ^model_name and p.active == true)
  |> order_by([p], desc: p.priority)
  |> limit(1)
  |> preload([:model, :engine])
  |> Repo.one()
end
```

### 5.3 Tabla de Decisión: Qué Hace el Pipeline Según el Input

| Input del cliente | `personality_hint` | `model_hint` | Resultado |
|---|---|---|---|
| `{"model": "gemma"}` (Anthropic) | `nil` | `"auto"` (mapeado) | DecisionEngine elige mejor personalidad |
| `{"model": "claude-sonnet"}` (Anthropic) | `nil` | nombre personalidad que usa ese modelo | Usa esa personalidad directamente |
| `{"model": "coder"}` (OpenAI) | `"coder"` | — | Busca personalidad "coder", la usa |
| `{"personality": "architect"}` (OpenAI) | `"architect"` | — | Usa personalidad "architect" directamente |
| `{"model": "gpt-4"}` (OpenAI, sin personalidad) | `nil` | `"gpt-4"` | Busca personalidad que use gpt-4, o auto-detecta |
| Sin modelo ni personalidad | `nil` | `"auto"` | DecisionEngine (keyword → embedding → LLM → default) |

### 5.4 Streaming: Mismo DecisionEngine para Ambos

El endpoint de streaming (`POST /v1/messages_stream`) también debe usar el DecisionEngine. Actualmente usa una lógica separada y más simple en `run_anthropic_stream/2`. Hay que unificarla:

```elixir
# FILE: lib/el_paso/http/server.ex
# MODIFICAR run_anthropic_stream/2 (líneas 531-616)

defp run_anthropic_stream(internal_req, conn) do
  # 1. Resolver personalidad igual que en el pipeline no-streaming
  personality_hint = Map.get(internal_req, :personality_hint) ||
                     internal_req.model_hint || "auto"

  {model_name, system_prompt, config_overrides, personality_name} =
    resolve_personality(personality_hint, internal_req.messages)

  # 2. Si se resolvió modelo, usarlo; si no, fallback
  resolved = {model_name, system_prompt, config_overrides}

  # ... (resto de la lógica de streaming, usando resolved)
end
```

---

## 6. CORRECCIONES, MEJORAS Y OPTIMIZACIONES ADICIONALES

### 6.1 Implementar Módulos Faltantes Referenciados pero No Existentes

Los siguientes módulos son referenciados en el código pero NO existen como archivos:

| Módulo referenciado | Archivo esperado | Acción |
|---------------------|------------------|--------|
| `ElPaso.Context.EmbeddingClient` | `lib/el_paso/context/embedding_client.ex` | **CREAR** |
| `ElPaso.Context.Tokenizer` | `lib/el_paso/context/tokenizer.ex` | N/A (reemplazado por `TokenCounter`) |
| `ElPaso.Context.Builder` | `lib/el_paso/context/builder.ex` | N/A (reemplazado por `ContextBuilder`) |
| `ElPaso.Context.Manager` | `lib/el_paso/context/manager.ex` | N/A (absorbido por `SessionContext`) |
| `ElPaso.Context.PrefixManager` | `lib/el_paso/context/prefix_manager.ex` | **CREAR** (cache de prefijos) |
| `ElPaso.Context.SummarizationWorker` | `lib/el_paso/context/summarization_worker.ex` | N/A (absorbido por `ContextSummarizer`) |
| `ElPaso.Context.SummarizationSupervisor` | `lib/el_paso/context/summarization_supervisor.ex` | **CREAR** |

#### 6.1.1 `EmbeddingClient`

```elixir
# FILE: lib/el_paso/context/embedding_client.ex
# NUEVO ARCHIVO

defmodule ElPaso.Context.EmbeddingClient do
  @moduledoc """
  Cliente para generar embeddings de texto usando Ollama + nomic-embed-text.

  El modelo de embeddings (nomic-embed-text, 274 MB, 768-dim, multiidioma)
  es verificado y descargado automáticamente por `ElPaso.Bootstrap` al arrancar.

  Soporte adicional (configurable):
    - OpenAI (text-embedding-3-small) si se configura api_key
    - bge-m3 (1.2 GB, 1024-dim) como alternativa de mayor calidad multilingüe

  Caché en ETS para no re-generar embeddings idénticos.
  TTL de caché: 1 hora (configurable).
  """

  use GenServer
  require Logger

  @cache_table :embedding_cache
  @default_model "nomic-embed-text"
  @default_url "http://localhost:11434/api/embeddings"

  # ── Client API ──

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Genera embedding para un texto. Usa caché ETS con TTL."
  def embed(text) do
    cache_key = :crypto.hash(:sha256, text) |> Base.encode16()
    case :ets.lookup(@cache_table, cache_key) do
      [{^cache_key, embedding, expires_at}] ->
        if System.monotonic_time(:second) < expires_at do
          {:ok, embedding}
        else
          :ets.delete(@cache_table, cache_key)
          GenServer.call(__MODULE__, {:embed, text, cache_key})
        end

      [] ->
        GenServer.call(__MODULE__, {:embed, text, cache_key})
    end
  end

  @doc """
  Verifica que el modelo de embeddings responde correctamente.
  Usado por `ElPaso.Bootstrap` durante el arranque.
  """
  def health_check do
    model = get_model_name()
    url = get_url()

    body = Jason.encode!(%{model: model, prompt: "health check"})
    headers = [{"content-type", "application/json"}]

    case Finch.build(:post, url, headers, body)
         |> Finch.request(ElPaso.Finch, receive_timeout: 10_000) do
      {:ok, %{status: 200, body: body}} ->
        embedding = Jason.decode!(body)["embedding"]
        if is_list(embedding) and length(embedding) == 768 do
          :ok
        else
          {:error, "Embedding dimension mismatch: expected 768, got #{length(embedding || [])}"}
        end

      {:ok, %{status: s}} ->
        {:error, "HTTP #{s}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Server ──

  @impl true
  def init(_) do
    :ets.new(@cache_table, [:named_table, :public, :set, read_concurrency: true])
    Logger.info("[EmbeddingClient] Inicializado. Modelo: #{get_model_name()}")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:embed, text, cache_key}, _from, state) do
    ttl = Application.get_env(:elpaso, :embedding_cache_ttl_sec, 3600)
    expires_at = System.monotonic_time(:second) + ttl

    case do_embed(text) do
      {:ok, embedding} ->
        # Verificar dimensión (debe ser 768 para nomic-embed-text)
        if length(embedding) == 768 do
          :ets.insert(@cache_table, {cache_key, embedding, expires_at})
          {:reply, {:ok, embedding}, state}
        else
          Logger.error("[EmbeddingClient] Dimensión inesperada: #{length(embedding)} (esperado 768)")
          {:reply, {:error, :dimension_mismatch}, state}
        end

      {:error, reason} ->
        Logger.warning("[EmbeddingClient] Fallo generando embedding: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  defp do_embed(text) do
    # Ollama es el proveedor principal. OpenAI es fallback opcional.
    case embed_via_ollama(text) do
      {:ok, embedding} -> {:ok, embedding}
      {:error, _} -> embed_via_openai(text)
    end
  end

  defp embed_via_ollama(text) do
    url = get_url()
    model = get_model_name()

    body = Jason.encode!(%{model: model, prompt: text})
    headers = [{"content-type", "application/json"}]

    case Finch.build(:post, url, headers, body)
         |> Finch.request(ElPaso.Finch, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, Jason.decode!(body)["embedding"]}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp embed_via_openai(text) do
    api_key = Application.get_env(:elpaso, :openai_api_key)
    if api_key do
      url = "https://api.openai.com/v1/embeddings"
      body = Jason.encode!(%{
        model: "text-embedding-3-small",
        input: text
      })
      headers = [
        {"content-type", "application/json"},
        {"authorization", "Bearer #{api_key}"}
      ]
      case Finch.build(:post, url, headers, body)
           |> Finch.request(ElPaso.Finch, receive_timeout: 30_000) do
        {:ok, %{status: 200, body: body}} ->
          {:ok, Jason.decode!(body)["data"] |> hd() |> Map.get("embedding")}

        error ->
          {:error, "OpenAI embedding failed: #{inspect(error)}"}
      end
    else
      {:error, :no_embedding_provider_available}
    end
  end

  defp get_model_name, do: Application.get_env(:elpaso, :embedding_model, @default_model)
  defp get_url, do: Application.get_env(:elpaso, :embedding_url, @default_url)
end
```

#### 5.1.2 `Bootstrap` — Verificación de Arranque

```elixir
# FILE: lib/el_paso/bootstrap.ex
# NUEVO ARCHIVO — Ver sección 0.2 para el código completo

defmodule ElPaso.Bootstrap do
  @moduledoc """
  Verificaciones pre-arranque:
    1. Ollama disponible
    2. nomic-embed-text descargado (si no, auto-descarga)
    3. Conexión a PostgreSQL con pgvector
    4. Tablas mínimas existen
  """

  require Logger

  @ollama_url "http://localhost:11434"

  def run! do
    verify_ollama!()
    verify_embedding_model!()
    verify_database!()
    :ok
  end

  def verify_ollama! do
    case Finch.build(:get, "#{@ollama_url}/api/tags")
         |> Finch.request(ElPaso.Finch, receive_timeout: 5_000) do
      {:ok, %{status: 200}} ->
        Logger.info("[Bootstrap] ✅ Ollama detected at #{@ollama_url}")
        :ok

      {:ok, %{status: s}} ->
        raise "Ollama returned HTTP #{s} at #{@ollama_url}"

      {:error, reason} ->
        raise """
        ❌ Ollama not available at #{@ollama_url}: #{inspect(reason)}

        Install Ollama: curl -fsSL https://ollama.com/install.sh | sh
        Then start it: ollama serve
        """
    end
  end

  def verify_embedding_model! do
    model = Application.get_env(:elpaso, :embedding_model, "nomic-embed-text")

    if model_available?(model) do
      Logger.info("[Bootstrap] ✅ Embedding model '#{model}' available")

      # Health check: verify it actually generates embeddings
      case ElPaso.Context.EmbeddingClient.health_check() do
        :ok -> Logger.info("[Bootstrap] ✅ Embedding health check OK")
        {:error, reason} ->
          Logger.warning("[Bootstrap] ⚠️ Embedding health check failed: #{reason}")
      end
    else
      IO.puts("")
      IO.puts("⬇  Modelo de embeddings '#{model}' (274 MB) no encontrado.")
      IO.puts("   Descargando automáticamente (solo la primera vez)...")
      IO.puts("   Tiempo estimado: 2-5 minutos según conexión.\n")

      case System.cmd("ollama", ["pull", model], stderr_to_stdout: true, into: IO.stream(:stdio, :line)) do
        {_, 0} ->
          IO.puts("\n✅ Modelo '#{model}' descargado.\n")
          Logger.info("[Bootstrap] ✅ '#{model}' downloaded successfully")

        {output, code} ->
          raise """
          ❌ Failed to download '#{model}' (exit code #{code}):
          #{output}

          Download it manually: ollama pull #{model}
          Then restart ElPaso.
          """
      end
    end

    :ok
  end

  def verify_database! do
    # Verificar que pgvector está instalado
    case ElPaso.Repo.query("SELECT 1 FROM pg_extension WHERE extname = 'vector'") do
      {:ok, %{num_rows: 1}} ->
        Logger.info("[Bootstrap] ✅ pgvector extension detected")

      _ ->
        raise """
        ❌ pgvector extension not found in PostgreSQL.
        Install it: CREATE EXTENSION vector;
        Or: sudo apt install postgresql-14-pgvector
        """
    end
  end

  defp model_available?(model_name) do
    case Finch.build(:get, "#{@ollama_url}/api/tags")
         |> Finch.request(ElPaso.Finch, receive_timeout: 5_000) do
      {:ok, %{status: 200, body: body}} ->
        models = Jason.decode!(body) |> Map.get("models", [])
        Enum.any?(models, fn m -> String.starts_with?(m["name"], model_name) end)

      _ -> false
    end
  end
end
```

### 6.2 Mejoras de Performance

#### 6.2.1 Caché de Decisiones de Routing

```elixir
# FILE: lib/el_paso/domain/decision_engine/decision_cache.ex
# NUEVO ARCHIVO

defmodule ElPaso.Domain.DecisionEngine.DecisionCache do
  @moduledoc """
  Caché en ETS para decisiones de routing.
  Evita re-evaluar el mismo prompt exacto.
  Hash del contenido → personalidad elegida.
  TTL: 5 minutos (configurable).
  """

  @table :routing_decision_cache
  @default_ttl_ms 300_000

  def init do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
  end

  def get(content) do
    hash = hash_content(content)
    case :ets.lookup(@table, hash) do
      [{^hash, personality_name, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:hit, personality_name}
        else
          :ets.delete(@table, hash)
          :miss
        end
      [] ->
        :miss
    end
  end

  def put(content, personality_name, ttl_ms \\ @default_ttl_ms) do
    hash = hash_content(content)
    expires_at = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(@table, {hash, personality_name, expires_at})
  end

  defp hash_content(content) do
    :crypto.hash(:sha256, String.downcase(content)) |> Base.encode16()
  end
end
```

#### 6.2.2 Conexión Pooling para Finch (ya configurado en application.ex)

Verificar que `ElPaso.Finch` tiene un pool size adecuado:

```elixir
# En application.ex, modificar:
{Finch, name: ElPaso.Finch, pools: %{
  :default => [size: 10, count: 5],
  "http://localhost:11434" => [size: 5, count: 3]
}}
```

### 6.3 Mejoras de Seguridad

#### 6.3.1 API Key en Model Schema (A05 Security Misconfig)

**Problema:** El campo `api_key` se almacena en texto plano en PostgreSQL dentro del schema `models`.

**Fix:** Encriptar en reposo usando `:crypto` con una clave maestra derivada de `ELPASO_MASTER_KEY`.

```elixir
# FILE: lib/el_paso/security/secrets.ex
# NUEVO ARCHIVO

defmodule ElPaso.Security.Secrets do
  @moduledoc """
  Encriptación/desencriptación de secrets en reposo.

  Usa AES-256-GCM con clave derivada de ELPASO_MASTER_KEY.
  Si no se configura, usa clave por defecto (SOLO para desarrollo).
  """

  @aad "elpaso-v1"

  def encrypt(plaintext) do
    key = get_key()
    iv = :crypto.strong_rand_bytes(12)
    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, true)
    Base.encode64(iv <> tag <> ciphertext)
  end

  def decrypt(encrypted) do
    key = get_key()
    <<iv::12-binary, tag::16-binary, ciphertext::binary>> = Base.decode64!(encrypted)
    :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false)
  end

  defp get_key do
    case System.get_env("ELPASO_MASTER_KEY") do
      nil ->
        if Application.get_env(:elpaso, :env) == :prod do
          raise "ELPASO_MASTER_KEY no está configurada en producción"
        else
          # Clave de desarrollo (NO USAR EN PROD)
          :crypto.hash(:sha256, "elpaso-dev-key-do-not-use-in-prod")
        end

      key_str ->
        :crypto.hash(:sha256, key_str)
    end
  end
end
```

Aplicar en el changeset de Model:

```elixir
# En lib/el_paso/models/model.ex, modificar changeset:
def changeset(model, attrs) do
  attrs = if attrs[:api_key] && attrs[:api_key] != "" do
    Map.put(attrs, :api_key, ElPaso.Security.Secrets.encrypt(attrs[:api_key]))
  else
    attrs
  end

  model
  |> cast(attrs, [...])
  # ...
end
```

#### 6.3.2 Rate Limiting por IP ya implementado — Verificar cobertura

El `RateLimiter` usa ETS para tracking. Añadir rate limiting también al endpoint `/v1/chat/completions`:

```elixir
# En lib/el_paso/http/server.ex, post "/v1/chat/completions" (línea 51):
post "/v1/chat/completions" do
  client_ip = get_client_ip(conn)

  case ElPaso.Security.RateLimiter.check_rate("chat:#{client_ip}", 60) do
    :ok ->
      # ... lógica existente
    {:error, :rate_limited} ->
      send_rate_limited(conn)
  end
end
```

#### 6.3.3 Log Injection Prevention (A09)

```elixir
# En lib/el_paso/http/server.ex, línea 59:
# ACTUAL (VULNERABLE a log injection):
Logger.info("[HTTP] POST /v1/chat/completions personality=#{personality_hint}")

# CORREGIDO (sanitizar input para logs):
Logger.info("[HTTP] POST /v1/chat/completions personality=#{sanitize_for_log(personality_hint)}")

defp sanitize_for_log(str) when is_binary(str) do
  String.replace(str, ~r/[\n\r\t]/, " ") |> String.slice(0, 128)
end
```

### 6.4 Mejoras de Código y Arquitectura

#### 6.4.1 Extraer `@task_categories` a Configuración

```elixir
# En config/config.exs, añadir:
config :elpaso, :task_categories, %{
  code: %{keywords: %{"function" => 4, ...}},
  # ...
}
```

Esto permite que los usuarios añadan categorías sin modificar código.

#### 6.4.2 Tests Faltantes para el Router con Personalidades

El archivo `test/el_paso/domain/router_test.exs` solo prueba `select_model/2` (API legacy). No hay tests para `select_personality/1` con personalidades reales en BD.

```elixir
# FILE: test/el_paso/domain/router_personality_test.exs
# NUEVO ARCHIVO

defmodule ElPaso.Domain.RouterPersonalityTest do
  use ElPaso.DataCase, async: false

  alias ElPaso.Domain.{Router, PersonalityManager}
  alias ElPaso.Repo
  alias ElPaso.Models.{Personality, Model, Engine}

  setup do
    # Crear engine, modelo, y personalidades de prueba
    {:ok, engine} = Repo.insert(%Engine{
      name: "test-engine",
      adapter: "ollama",
      base_url: "http://localhost:11434"
    })

    {:ok, model} = Repo.insert(%Model{
      name: "test-model",
      engine_id: engine.id,
      active: true
    })

    {:ok, coder} = PersonalityManager.create_personality(%{
      name: "coder",
      system_prompt: "You are a coder",
      semantic_description: "Software development expert",
      model_id: model.id,
      engine_id: engine.id,
      trigger_keywords: ["function", "implement", "code", "refactor"],
      trigger_task_types: ["code"],
      priority: 10
    })

    {:ok, general} = PersonalityManager.create_personality(%{
      name: "general",
      system_prompt: "You are a helpful assistant",
      semantic_description: "General purpose assistant for any task",
      model_id: model.id,
      engine_id: engine.id,
      trigger_keywords: [],
      trigger_task_types: [],
      priority: 1,
      is_default: true
    })

    %{coder: coder, general: general}
  end

  describe "select_personality/1" do
    test "selects coder for code-related prompts", %{coder: coder} do
      {:ok, result} = Router.select_personality([
        %{content: "implement a function to sort a list"}
      ])
      assert result.personality_name == "coder"
    end

    test "falls back to default for generic prompts", %{general: general} do
      {:ok, result} = Router.select_personality([
        %{content: "hello, how are you?"}
      ])
      assert result.personality_name == "general"
    end

    test "handles multi-word triggers" do
      # Asumiendo que hay una personalidad con trigger "to english"
      {:ok, result} = Router.select_personality([
        %{content: "translate this to english please"}
      ])
      # Debería matchear la personalidad correcta, no caer en default
      refute result.decision_reason =~ "default"
    end

    test "returns error when no active personalities" do
      # Desactivar todas
      Repo.update_all(Personality, set: [active: false])
      assert {:error, :no_active_personality} = Router.select_personality([
        %{content: "test"}
      ])
    end
  end
end
```

#### 6.4.3 Eliminar Dependencia Circular Potencial

- `Router` → `PersonalityManager` → `Personality` (schema)
- `PersonalityManager` usa `Repo` directamente — OK

No hay dependencias circulares actualmente, pero el nuevo `DecisionEngine` debe tener cuidado:
- `DecisionEngine.LLMClassifier` → `ModelManager.infer()` → posible bucle si el clasificador también pasa por el router. **Usar inferencia directa sin routing.**

#### 6.4.4 Estandarizar Formato de Mensajes

Actualmente los mensajes vienen en 3 formatos diferentes:
```elixir
%{"role" => "user", "content" => "text"}  # string keys
%{role: "user", content: "text"}          # atom keys
%{content: "text"}                         # sin role
```

Crear un normalizador único:

```elixir
# FILE: lib/el_paso/http/message_normalizer.ex
# NUEVO ARCHIVO

defmodule ElPaso.HTTP.MessageNormalizer do
  @moduledoc """
  Normaliza mensajes a formato canónico: [{:role, :content}] con atom keys.
  """

  def normalize(messages) when is_list(messages) do
    Enum.map(messages, &normalize_one/1)
  end

  defp normalize_one(%{"role" => role, "content" => content}), do: %{role: role, content: content}
  defp normalize_one(%{role: role, content: content}), do: %{role: role, content: content}
  defp normalize_one(%{"content" => content}), do: %{role: "user", content: content}
  defp normalize_one(%{content: content}), do: %{role: "user", content: content}
  defp normalize_one(other) when is_binary(other), do: %{role: "user", content: other}
  defp normalize_one(_), do: %{role: "user", content: ""}
end
```

### 6.5 Mejoras del CLI

#### 6.5.1 Comando `personality embed`

```elixir
# Añadir al CLI de personality:
["embed"] ->
  PersonalityManager.regenerate_all_embeddings()
  Output.success("Embeddings regenerados para todas las personalidades activas")
```

#### 6.5.2 Comando `session`

```elixir
# Nuevo comando CLI: mix elpaso session
#   session list     → lista sesiones activas
#   session show ID  → muestra estado de una sesión
#   session clean    → limpia sesiones inactivas
```

### 6.6 Migraciones Pendientes

Crear una nueva migración consolidada:

```elixir
# FILE: priv/repo/migrations/VERSION_decision_engine_v4.exs

defmodule ElPaso.Repo.Migrations.DecisionEngineV4 do
  use Ecto.Migration

  def up do
    # 1. Añadir campos semánticos a personalities
    alter table(:personalities) do
      add :semantic_description, :text
      add :embedding, :vector, size: 768
      add :regex_patterns, {:array, :string}, default: []
      add :min_confidence, :float, default: 0.5
      add :cooldown_ms, :integer, default: 0
    end

    create index(:personalities, [:embedding], using: :ivfflat, with: "lists = 10")

    # 2. Actualizar personalidades existentes con semantic_description
    execute """
    UPDATE personalities
    SET semantic_description = COALESCE(description, name)
    WHERE semantic_description IS NULL;
    """

    # 3. Añadir campo personality_name a routing_decisions
    alter table(:routing_decisions) do
      add :personality_name, :string
      add :decision_layer, :string
      add :confidence, :float
    end
  end

  def down do
    alter table(:personalities) do
      remove :semantic_description
      remove :embedding
      remove :regex_patterns
      remove :min_confidence
      remove :cooldown_ms
    end

    alter table(:routing_decisions) do
      remove :personality_name
      remove :decision_layer
      remove :confidence
    end
  end
end
```

---

## 7. REQUISITOS DE DOCUMENTACIÓN (README)

### 7.1 Secciones Obligatorias en el README

El README (`README.md` y `README_ES.md`) debe incluir las siguientes secciones nuevas o actualizadas:

#### 7.1.1 Requisitos del Sistema (NUEVO)

```markdown
## Requisitos del sistema

### Software requerido
- **Elixir** 1.19+ y **Erlang/OTP** 28+ (solo para desarrollo; producción usa EScript)
- **PostgreSQL** 14+ con extensión **pgvector** (`CREATE EXTENSION vector;`)
- **Ollama** (https://ollama.com) — servidor de modelos local
  - ElPaso usa Ollama para DOS propósitos:
    1. **Modelo de embeddings** `nomic-embed-text` (274 MB) — obligatorio para el motor de decisiones semántico
    2. **Modelos de inferencia** (gemma, llama, qwen, etc.) — según configuración del usuario

### Hardware mínimo

| Escenario | RAM | Disco | GPU |
|---|---|---|---|
| **Mínimo (APIs remotas + embeddings)** | 2 GB | 5 GB | No |
| **Mínimo (1 modelo local pequeño)** | 6 GB | 10 GB | No (CPU) |
| **Recomendado (2-3 modelos medianos)** | 16 GB | 30 GB | 6+ GB VRAM |
| **Producción (modelos grandes + multi-usuario)** | 32 GB | 100 GB | 12+ GB VRAM |

> ⚠️ ElPaso + PostgreSQL + Ollama + nomic-embed-text consumen ~800 MB de RAM base.
> El resto del consumo depende de los modelos de inferencia que configures.
> 
> ℹ️ Si solo usas APIs remotas (OpenAI, Anthropic), el requisito mínimo es 2 GB de RAM.
```

#### 7.1.2 Modelo de Embeddings (NUEVO)

```markdown
## Modelo de embeddings

ElPaso v4.0 utiliza **`nomic-embed-text`** como modelo de embeddings para el motor
de decisiones semántico. Este modelo:

| Característica | Valor |
|---|---|
| **Nombre Ollama** | `nomic-embed-text` |
| **Tamaño** | 274 MB (descarga única) |
| **Dimensiones** | 768 (vectores de 768 floats) |
| **Idiomas** | 100+ (español, inglés, francés, alemán, chino, japonés, etc.) |
| **RAM requerida** | ~300 MB |

### Descarga automática

Al arrancar con `elpaso server start`, ElPaso verifica automáticamente:
1. Que Ollama está corriendo en `localhost:11434`
2. Que `nomic-embed-text` está descargado

Si el modelo no está descargado, ElPaso lo descarga automáticamente
(274 MB, ~2-5 minutos). Solo ocurre la primera vez.

### Modelo alternativo (mayor calidad)

Si tu hardware lo permite, puedes configurar `bge-m3` (1.2 GB, 1024-dimensiones)
como alternativa de mayor calidad multilingüe:

```ini
# En ~/.config/elpaso/elpaso.conf
[embeddings]
model = bge-m3
```

Luego regenera los embeddings de las personalidades:
```bash
mix elpaso personality embed
```

### Cómo usa ElPaso los embeddings

El motor de decisiones de ElPaso tiene 4 capas. La **Capa 2 (Embedding Similarity)**
compara la similitud semántica entre el prompt del usuario y la descripción de cada
personalidad:

1. El prompt del usuario se convierte en un vector de 768 dimensiones
2. Se compara (cosine similarity) contra los embeddings precomputados de cada personalidad
3. La personalidad más cercana semánticamente recibe mayor puntuación

Esto permite que ElPaso entienda que "necesito ayuda con un bug en mi código Rust"
es similar a la personalidad "coder" aunque no contenga las keywords exactas.
```

#### 7.1.3 Configuración de Personalidades (ACTUALIZADO)

```markdown
## Personalidades

### Crear una personalidad

```bash
mix elpaso personality add <nombre> \
  --model <nombre-modelo> \
  --engine <nombre-engine> \
  --system-prompt "<prompt del sistema>" \
  --semantic-description "<descripción para búsqueda semántica>" \
  --keywords "keyword1,keyword2,keyword3" \
  --task-types "code,debug" \
  --regex-patterns "\\\\b(fn|function|def)\\\\b" \
  --priority 10 \
  --min-confidence 0.6 \
  [--default]
```

### Campos importantes

| Campo | Obligatorio | Descripción |
|---|---|---|
| `--name` | ✅ | Nombre único de la personalidad |
| `--system-prompt` | ✅ | Prompt del sistema que recibe el modelo |
| `--semantic-description` | ✅ | **NUEVO v4.0**: Descripción en lenguaje natural para búsqueda semántica. Ej: "Experto en desarrollo de software. Escribe código idiomático, depura errores, implementa features y escribe tests." |
| `--keywords` | No | Palabras clave que activan esta personalidad (triggers explícitos) |
| `--task-types` | No | Tipos de tarea: code, reasoning, translation, creative, legal, etc. |
| `--regex-patterns` | No | **NUEVO v4.0**: Patrones regex para detección avanzada. Ej: `\\b(fn|function|class)\\b` |
| `--priority` | No | Prioridad (mayor = más preferencia cuando hay empate). Default: 0 |
| `--min-confidence` | No | **NUEVO v4.0**: Confianza mínima (0.0-1.0) para auto-activación. Default: 0.5 |
| `--default` | No | Marca esta personalidad como fallback. Solo una puede ser default. |

### Cómo ElPaso elige la personalidad

El **DecisionEngine** de ElPaso evalúa cada solicitud en 4 capas:

1. **Keyword + Regex matching** (<1ms): Si el prompt contiene palabras clave o patrones regex configurados, se activa la personalidad correspondiente.
2. **Embedding similarity** (~10ms): Compara el significado semántico del prompt contra la `semantic_description` de cada personalidad usando embeddings y cosine similarity (pgvector).
3. **LLM classifier** (~500ms, solo si hay ambigüedad): Un modelo pequeño clasifica la intención del usuario.
4. **Default fallback**: Si nada coincide, se usa la personalidad marcada como `--default`.
```

#### 7.1.4 Endpoints Disponibles (ACTUALIZADO)

```markdown
## Endpoints HTTP

ElPaso expone los siguientes endpoints en `http://localhost:8080`:

### OpenAI-compatible
| Método | Ruta | Descripción |
|---|---|---|
| `POST` | `/v1/chat/completions` | Chat completions (formato OpenAI). Compatible con opencode, vscode, zed. |
| `GET` | `/models/status` | Estado de modelos |

### Anthropic-compatible
| Método | Ruta | Descripción |
|---|---|---|
| `POST` | `/v1/messages` | Messages (formato Anthropic). Compatible con Claude Code, openclaw. |
| `POST` | `/v1/messages_stream` | Streaming SSE (Server-Sent Events). Compatible con Claude Code streaming. |

### Administración
| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/metrics` | Métricas Prometheus |
| `GET` | `/status` | Estado del sistema + alertas de degradación |
| `GET` | `/dashboard` | Dashboard web |
| `POST` | `/auth/token` | Autenticación JWT |
| `GET` | `/admin/*` | Endpoints de admin (requiere JWT admin) |

### Cómo seleccionar personalidad desde el cliente

**Opción A — Auto-detección (recomendado):**
```bash
# OpenAI
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "refactoriza esta función en Rust"}]}'

# Anthropic
curl -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"model": "auto", "messages": [{"role": "user", "content": "diseña la arquitectura de microservicios"}]}'
```

**Opción B — Personalidad explícita:**
```bash
# OpenAI: campo "model" o "personality"
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "architect", "messages": [{"role": "user", "content": "diseña un sistema"}]}'

# Anthropic: campo "personality" (custom de ElPaso)
curl -X POST http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet", "personality": "coder", "messages": [{"role": "user", "content": "..."}]}'
```
```

---

## 📊 RESUMEN DE ENTREGABLES

### Archivos Nuevos (CREAR)

| # | Archivo | Complejidad |
|---|---------|-------------|
| 0 | `lib/el_paso/bootstrap.ex` | MEDIA |
| 1 | `lib/el_paso/domain/decision_engine.ex` | ALTA |
| 2 | `lib/el_paso/domain/decision_engine/scorer.ex` | MEDIA |
| 3 | `lib/el_paso/domain/decision_engine/embedding_matcher.ex` | ALTA |
| 4 | `lib/el_paso/domain/decision_engine/llm_classifier.ex` | MEDIA |
| 5 | `lib/el_paso/domain/decision_engine/decision_cache.ex` | BAJA |
| 6 | `lib/el_paso/domain/router/task_categories.ex` | BAJA |
| 7 | `lib/el_paso/context/session_context.ex` | ALTA |
| 8 | `lib/el_paso/context/context_builder.ex` | MEDIA |
| 9 | `lib/el_paso/context/context_summarizer.ex` | MEDIA |
| 10 | `lib/el_paso/context/token_counter.ex` | BAJA |
| 11 | `lib/el_paso/context/session_supervisor.ex` | BAJA |
| 12 | `lib/el_paso/context/embedding_client.ex` | MEDIA |
| 13 | `lib/el_paso/context/prefix_manager.ex` | BAJA |
| 14 | `lib/el_paso/http/message_normalizer.ex` | BAJA |
| 15 | `lib/el_paso/security/secrets.ex` | MEDIA |
| 16 | `priv/repo/migrations/VERSION_decision_engine_v4.exs` | MEDIA |
| 17 | `test/el_paso/domain/decision_engine_test.exs` | ALTA |
| 18 | `test/el_paso/domain/router_personality_test.exs` | MEDIA |
| 19 | `test/el_paso/context/session_context_test.exs` | ALTA |
| 20 | `test/el_paso/context/context_builder_test.exs` | MEDIA |

### Archivos Modificados (EDITAR)

| # | Archivo | Cambio |
|---|---------|--------|
| 1 | `lib/el_paso/domain/router.ex` | Delegar en DecisionEngine; fix extract_keywords |
| 2 | `lib/el_paso/http/server.ex` | Integrar SessionContext; rate limiting; log sanitization; pipeline unificado |
| 3 | `lib/el_paso/http/anthropic/proxy.ex` | Mapear modelo Anthropic a personalidad; preservar modelo solicitado |
| 4 | `lib/el_paso/models/personality.ex` | Nuevos campos; embedding hook |
| 5 | `lib/el_paso/domain/personality_manager.ex` | Funciones de embedding; semantic_description; find_by_model_name |
| 6 | `lib/el_paso/application.ex` | Añadir Bootstrap, SessionRegistry, SessionSupervisor, EmbeddingClient |
| 7 | `lib/mix/tasks/elpaso/personality.ex` | Nuevos flags: semantic-description, regex-patterns, min-confidence |
| 8 | `lib/el_paso/models/model.ex` | Encriptar api_key |
| 9 | `README.md` + `README_ES.md` | Nuevas secciones: requisitos, modelo embeddings, endpoints, personalidades |

### Orden de Implementación Recomendado

```
Fase 0 (Prerrequisitos — ANTES que todo):
  □ 0.1  Crear bootstrap.ex (verificación de Ollama + nomic-embed-text + pgvector)
  □ 0.2  Integrar Bootstrap.run!/0 en el arranque de server start
  □ 0.3  Verificar que Ollama y el modelo de embeddings funcionan antes de aceptar requests

Fase 1 (Fundación):
  □ 1.1  Fix inmediato de extract_keywords en router.ex (BUG #1)
  □ 1.2  Crear task_categories.ex (extraer de router.ex)
  □ 1.3  Crear message_normalizer.ex

Fase 2 (Decision Engine):
  □ 2.1  Crear embedding_client.ex (con health_check para Bootstrap)
  □ 2.2  Crear scorer.ex
  □ 2.3  Crear embedding_matcher.ex
  □ 2.4  Crear llm_classifier.ex
  □ 2.5  Crear decision_cache.ex
  □ 2.6  Crear decision_engine.ex (orquestador)
  □ 2.7  Modificar router.ex para delegar en DecisionEngine
  □ 2.8  Crear migración de schema

Fase 3 (Sala Común):
  □ 3.1  Crear token_counter.ex
  □ 3.2  Crear context_summarizer.ex
  □ 3.3  Crear context_builder.ex
  □ 3.4  Crear session_context.ex
  □ 3.5  Crear session_supervisor.ex
  □ 3.6  Modificar server.ex para integrar SessionContext en ambos pipelines
  □ 3.7  Modificar application.ex para nuevos children

Fase 4 (Compatibilidad Dual OpenAI/Anthropic):
  □ 4.1  Modificar AnthropicProxy.from_anthropic para mapear modelo a personalidad
  □ 4.2  Añadir PersonalityManager.find_by_model_name/1
  □ 4.3  Unificar run_anthropic_stream con el mismo DecisionEngine
  □ 4.4  Verificar que ambos endpoints (OpenAI y Anthropic) pasan por el mismo pipeline

Fase 5 (Seguridad y Mejoras):
  □ 5.1  Crear secrets.ex y modificar model.ex (encriptar api_key)
  □ 5.2  Añadir rate limiting a /v1/chat/completions
  □ 5.3  Sanitizar logs (anti log-injection)
  □ 5.4  Modificar CLI de personality (nuevos flags)
  □ 5.5  Crear prefix_manager.ex (caché de system prompts)

Fase 6 (Documentación):
  □ 6.1  Actualizar README.md con requisitos de sistema
  □ 6.2  Documentar modelo de embeddings (nomic-embed-text, tamaño, descarga automática)
  □ 6.3  Documentar endpoints OpenAI y Anthropic
  □ 6.4  Documentar creación de personalidades con nuevos campos
  □ 6.5  Actualizar README_ES.md (versión en español)

Fase 7 (Tests):
  □ 7.1  Tests de DecisionEngine
  □ 7.2  Tests de Router con personalidades
  □ 7.3  Tests de SessionContext
  □ 7.4  Tests de ContextBuilder
  □ 7.5  Tests de EmbeddingClient (mockeando Ollama)
  □ 7.6  Tests de Bootstrap
  □ 7.7  Ejecutar mix test --cover y verificar > 75%
```

---

## ⚠️ NOTAS PARA EL AGENTE IMPLEMENTADOR

1. **NO modificar la lógica de negocio existente sin entenderla completamente.** Lee los archivos antes de tocarlos.

2. **El `ModelManager.infer/3` NUNCA debe pasar por el Router.** Si `LLMClassifier` llama a `ModelManager.infer`, esto va directo al modelo, sin routing. De lo contrario, el clasificador podría recursivamente invocarse a sí mismo.

3. **Los embeddings son costosos.** Implementa caché agresivo (ETS + hash del contenido). No regeneres embeddings para personalidades a menos que su `semantic_description` cambie.

4. **El modelo de embeddings `nomic-embed-text` (274 MB) es OBLIGATORIO.** El código debe asumirlo. La verificación y descarga automática ocurren en `Bootstrap.run!/0` ANTES de que el servidor HTTP acepte conexiones. Sin este modelo, ElPaso no puede arrancar.

5. **Dimensiones de embedding fijas a 768.** `nomic-embed-text` produce vectores de 768 dimensiones. La migración pgvector debe usar `size: 768`. Si en el futuro se soporta `bge-m3` (1024-dim), la migración debe ser independiente.

6. **Ollama es requerido.** ElPaso v4.0 requiere Ollama como servidor de modelos. Sin Ollama, no hay embeddings y el DecisionEngine solo puede usar las capas 1 (keyword) y 4 (default). El Bootstrap debe fallar explícitamente si Ollama no está disponible.

7. **Ambos endpoints (OpenAI y Anthropic) deben pasar por el MISMO pipeline de decisión.** La única diferencia debe ser el formato de entrada/salida (parseo/respuesta). La resolución de personalidad es idéntica.

8. **La migración debe ser idempotente.** Usa `ON CONFLICT DO NOTHING` y verifica existencia de columnas antes de añadirlas.

9. **Todos los nuevos GenServers deben tener `child_spec` y timeout de inicialización.**

10. **No hagas `git commit` ni `git push`.** Si necesitas commit, entrega el mensaje para que el usuario lo ejecute.

11. **El orden de compilación importa.** Los módulos se compilan en orden alfabético dentro de `lib/`. Si `decision_engine.ex` depende de `decision_engine/scorer.ex`, asegúrate de que el orden de archivos no cause error de compilación (Elixir maneja esto bien en el mismo directorio, pero tenlo en cuenta).

12. **Tests deben usar `async: false`** cuando modifiquen la BD (usan `DataCase` con sandbox).

13. **Tests de EmbeddingClient deben mockear Ollama.** No asumas que Ollama está corriendo en CI. Usa `Bypass` o mocks para simular el endpoint de embeddings.

14. **El campo `semantic_description` es obligatorio** al crear personalidades con el CLI. Sin él, el `EmbeddingMatcher` no puede funcionar. Si se omite, el CLI debe mostrar un error claro.

15. **Las especificaciones de hardware en el README deben ser realistas.** 6 GB RAM mínimo con 1 modelo local pequeño. 2 GB RAM mínimo si solo se usan APIs remotas. El consumo real de nomic-embed-text son ~300 MB en RAM, no 274 MB (el tamaño de descarga es comprimido).

---

**Fin del plan de auditoría v4.0.**
