# 📋 TAREAS PENDIENTES — ELPASO v4.0

**Fecha:** 2026-05-11
**Versión:** v4.0
**Documento de referencia:** `PLAN_AUDITORIA_V4.md` (3049 líneas)
**Documento de estado:** `ESTADO_ACTUAL_V4.md` (338 líneas)

---

## 🔬 DIAGNÓSTICO DEL DECISIONENGINE

### ¿Está terminado?

**Respuesta corta:** Arquitectónicamente SÍ. Operativamente NO.

El código de las 4 capas está escrito y compila, pero dos de las cuatro capas no pueden funcionar en producción porque les faltan los datos y modelos que necesitan:

```
Capa 1 (Keyword)        ✅ Funcional — solo necesita personalidades con trigger_keywords
Capa 2 (Embedding)      ❌ Inoperable — las personalidades no tienen embeddings generados
Capa 3 (LLM Classifier) ❌ Inoperable — no existe un modelo con tag [classifier]
Capa 4 (Default)        ✅ Funcional — solo necesita una personalidad con is_default: true
```

**Resultado neto:** El DecisionEngine hoy solo puede usar Capa 1 (scoring por keywords) y Capa 4 (fallback al default). Las capas 2 y 3 están implementadas pero su flujo nunca se alcanza:

- **Capa 2 (EmbeddingMatcher):** ejecuta `from(p in Personality, where: not is_nil(p.embedding))`. Como ninguna personalidad tiene embedding generado, devuelve `{:error, :no_embeddings_available}` y el orquestador salta a la capa 3.
- **Capa 3 (LLMClassifier):** busca un modelo con `description LIKE "%[classifier]%"`. Como ningún modelo tiene ese tag, devuelve `{:error, :no_classifier_model}` y cae en la capa 4.

Esto implica que **el bug original "gemma siempre gana" está mitigado pero no completamente resuelto**. El scoring por keywords (capa 1) con n-gramas y substring matching es mucho mejor que antes, pero si ninguna personalidad matchea con confianza ≥ 0.70, el sistema sigue cayendo en el default. La capa semántica (embedding) que realmente resolvería casos ambiguos no se activa nunca.

---

## 🔴 BLOQUEANTE

### B1. Zaguan no compila

| Campo | Detalle |
|-------|---------|
| **Archivo** | `lib/zaguan/tui/input.ex:415` |
| **Error** | `do` sin `end` correspondiente — error de sintaxis Elixir |
| **Impacto** | ElPaso no puede compilarse ni arrancarse como proyecto completo |
| **Estado** | Otro agente está trabajando en ello |
| **Plan B** | Si se estanca, se puede hacer que Zaguan sea una dependencia opcional (`optional: true` en mix.exs) para que ElPaso pueda compilar y ejecutarse sin el TUI |

---

## 🔴 TAREAS CRÍTICAS (hacen que el DecisionEngine funcione de verdad)

### T1. Generar embeddings para personalidades

**Archivo a modificar:** `lib/el_paso/domain/personality_manager.ex`

**Situación actual:** `PersonalityManager` solo tiene CRUD básico. No hay funciones para generar ni almacenar embeddings.

**Qué hay que implementar:**

```elixir
# Añadir a personality_manager.ex:

@doc """
Genera y almacena el embedding de UNA personalidad usando EmbeddingClient.
Usa el campo semantic_description (o description como fallback) como texto fuente.
"""
def embed_personality(%Personality{} = p) do
  text = p.semantic_description || p.description || p.name
  case ElPaso.Context.EmbeddingClient.embed(text) do
    {:ok, embedding} ->
      p
      |> Personality.changeset(%{embedding: Pgvector.new(embedding)})
      |> Repo.update()

    {:error, reason} ->
      {:error, reason}
  end
end

@doc """
Genera y almacena embeddings para TODAS las personalidades activas.
Útil tras cambiar de modelo de embeddings (nomic-embed-text → bge-m3).
"""
def embed_all do
  list_active()
  |> Enum.map(&embed_personality/1)
  |> Enum.split_with(fn result -> match?({:ok, _}, result) end)
end

@doc """
Genera y almacena el embedding para una personalidad por nombre.
"""
def embed_by_name(name) do
  case get_personality(name) do
    nil -> {:error, :not_found}
    personality -> embed_personality(personality)
  end
end
```

**Decisión de diseño:** El texto fuente para el embedding debe ser `semantic_description` si existe, con fallback a `description` y luego `name`. Esto permite que el administrador escriba una descripción semántica rica (ej: "Especialista en traducción entre inglés y español, maneja modismos, jerga técnica y localización de software") que capture la esencia de la personalidad mejor que las keywords.

**Dependencias:** Requiere que `EmbeddingClient` esté corriendo (Ollama + modelo descargado).

---

### T2. Comando CLI `mix elpaso personality embed`

**Archivo a crear/modificar:** `lib/mix/tasks/elpaso/personality/embed.ex`

**Situación actual:** El Bootstrap imprime `"Para regenerar embeddings de personalidades: mix elpaso personality embed"` pero el comando no existe.

**Qué hay que implementar:**

```elixir
defmodule Mix.Tasks.ElPaso.Personality.Embed do
  use Mix.Task
  @shortdoc "Genera embeddings para personalidades (requerido para el DecisionEngine capa 2)"

  @moduledoc """
  Genera embeddings vectoriales para las personalidades activas.

  Uso:
    mix elpaso.personality.embed           # Regenera todas
    mix elpaso.personality.embed --name coder  # Solo una
    mix elpaso.personality.embed --dry-run # Muestra qué haría sin ejecutar
  """

  @switches [name: :string, dry_run: :boolean]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    Mix.Task.run("app.start")

    if opts[:dry_run] do
      personalities = ElPaso.Domain.PersonalityManager.list_active()
      IO.puts("Se generarían embeddings para #{length(personalities)} personalidades:")
      Enum.each(personalities, fn p ->
        text = p.semantic_description || p.description || p.name
        IO.puts("  - #{p.name}: \"#{String.slice(text, 0, 80)}...\"")
      end)
    else
      case opts[:name] do
        nil ->
          {ok, errors} = ElPaso.Domain.PersonalityManager.embed_all()
          IO.puts("✅ #{length(ok)} embeddings generados")
          if errors != [], do: IO.puts("❌ #{length(errors)} errores: #{inspect(errors)}")

        name ->
          case ElPaso.Domain.PersonalityManager.embed_by_name(name) do
            {:ok, _} -> IO.puts("✅ Embedding generado para #{name}")
            {:error, reason} -> IO.puts("❌ Error: #{inspect(reason)}")
          end
      end
    end
  end
end
```

**Ubicación en el sistema de archivos:** `lib/mix/tasks/elpaso/personality/embed.ex` (siguiendo la convención de Elixir: `Mix.Tasks.ElPaso.Personality.Embed` → `lib/mix/tasks/elpaso/personality/embed.ex`)

---

### T3. Semilla de personalidades con embeddings precomputados

**Archivo a crear:** `priv/repo/seeds.exs` (o modificar el existente)

**Situación actual:** No hay seeds. Las personalidades hay que crearlas a mano una a una, lo cual hace imposible probar el DecisionEngine.

**Qué hay que crear:** Un script de seeds que genere al menos 5 personalidades de ejemplo con `semantic_description`, `trigger_keywords`, `regex_patterns` y genere sus embeddings:

```elixir
# priv/repo/seeds.exs
alias ElPaso.Repo
alias ElPaso.Domain.PersonalityManager
alias ElPaso.Models.Personality

# Asegurar que la app está arrancada (necesario para EmbeddingClient)
Application.ensure_all_started(:elpaso)

# 1. Crear engine Ollama si no existe
engine = case ElPaso.Repo.get_by(ElPaso.Models.Engine, name: "ollama-local") do
  nil ->
    {:ok, engine} = ElPaso.Domain.EngineManager.create_engine(%{
      name: "ollama-local",
      adapter: "ollama",
      base_url: "http://localhost:11434",
      active: true
    })
    engine
  engine -> engine
end

# 2. Crear modelos de ejemplo
models = [
  %{name: "qwen2.5:7b", description: "[classifier] Modelo rápido para clasificación de intenciones y resúmenes"},
  %{name: "gemma3:12b", description: "Modelo generalista para conversación y tareas cotidianas"},
  %{name: "deepseek-coder:6.7b", description: "Modelo especializado en código y programación"},
]
# ... (crear cada modelo con ModelManager)

# 3. Crear personalidades con semantic_description y triggers
personalities = [
  %{
    name: "coder",
    description: "Especialista en programación",
    semantic_description: "Experto en desarrollo de software, escritura de código, debugging, refactorización, arquitectura de sistemas, patrones de diseño, y mejores prácticas de ingeniería de software en múltiples lenguajes de programación",
    trigger_keywords: ["code", "código", "program", "debug", "refactor", "function", "clase", "api", "endpoint", "bug", "test", "compilar", "error de compilación", "write a script", "implementar", "typescript", "python", "elixir", "rust", "sql", "docker"],
    regex_patterns: ["(?i)\\b(código|code|programar?|debug|refactor|funci[oó]n|bug|test)\\b"],
    model_name: "deepseek-coder:6.7b",
    priority: 10,
    min_confidence: 0.6,
    is_default: false
  },
  %{
    name: "translator",
    description: "Traductor multilingüe",
    semantic_description: "Traductor profesional especializado en traducción entre idiomas, localización de software, adaptación cultural de contenido, y manejo de matices lingüísticos. Domina español, inglés, francés, alemán, y otros idiomas",
    trigger_keywords: ["translate", "traduc", "translation", "to english", "to spanish", "al inglés", "al español", "en français", "localize", "idioma", "language", "en español"],
    regex_patterns: ["(?i)\\b(traduc[ie]r?|translate|to (english|spanish|french))\\b"],
    model_name: "gemma3:12b",
    priority: 8,
    min_confidence: 0.55,
    is_default: false
  },
  %{
    name: "general",
    description: "Asistente general para conversación y tareas cotidianas",
    semantic_description: "Asistente conversacional versátil para consultas generales, explicaciones, brainstorming, escritura creativa, y tareas cotidianas que no requieren un especialista específico",
    trigger_keywords: ["hello", "hola", "help", "ayuda", "who are you", "qué eres", "explain", "explica"],
    regex_patterns: [],
    model_name: "gemma3:12b",
    priority: 1,
    min_confidence: 0.3,
    is_default: true
  },
  %{
    name: "summarizer",
    description: "Resumidor de textos y documentos",
    semantic_description: "Especialista en resumir documentos largos, artículos, papers académicos, hilos de conversación, y reportes. Extrae puntos clave, genera abstracts ejecutivos, y condensa información manteniendo los hechos esenciales",
    trigger_keywords: ["summarize", "resum", "summary", "resumen", "tldr", "síntesis", "abstract", "condense", "key points"],
    regex_patterns: ["(?i)\\b(summar|resum|tldr|s[ií]ntesis)\\b"],
    model_name: "gemma3:12b",
    priority: 7,
    min_confidence: 0.6,
    is_default: false
  },
  %{
    name: "reviewer",
    description: "Revisor de código y PRs",
    semantic_description: "Experto en revisión de código, pull requests, auditorías de seguridad, análisis de calidad, detección de bugs, code smells, y anti-patrones. Sigue las mejores prácticas de OWASP, clean code, y arquitectura de software",
    trigger_keywords: ["review", "revisar", "auditar", "audit", "code review", "pr", "pull request", "security", "seguridad", "vulnerabilidad", "bug", "code smell", "refactor"],
    regex_patterns: ["(?i)\\b(review|revisar|audit|code review|pull request)\\b"],
    model_name: "deepseek-coder:6.7b",
    priority: 9,
    min_confidence: 0.6,
    is_default: false
  },
]

# 4. Crear cada personalidad y generar su embedding
Enum.each(personalities, fn attrs ->
  model = ElPaso.Repo.get_by(ElPaso.Models.Model, name: attrs.model_name)
  {:ok, personality} = PersonalityManager.create_personality(Map.put(attrs, :model_id, model.id))
  PersonalityManager.embed_personality(personality)
end)

IO.puts("✅ Seeds completados: #{length(personalities)} personalidades con embeddings generados")
```

**Nota:** Los seeds deben ser idempotentes — si ya existen, no deben duplicarse.

---

### T4. Configurar un modelo clasificador (para Capa 3 del DecisionEngine)

**Situación actual:** `LLMClassifier` busca un modelo con `description LIKE "%[classifier]%"`. Ningún modelo lo tiene. La capa 3 siempre falla.

**Qué hay que hacer:**

1. Añadir un modelo pequeño/rápido (ej: `qwen2.5:3b`, `phi3:mini`, o cualquier modelo < 3B params) con `description: "[classifier] Modelo rápido para clasificación de intenciones"`
2. Este modelo DEBE ser diferente del modelo de embeddings — el classifier hace inferencia de texto (chat), no embeddings

**Comando manual:**
```bash
ollama pull qwen2.5:3b
mix elpaso model add --name qwen2.5:3b --engine ollama-local --description "[classifier] Modelo rápido para clasificación"
```

**Automatización en seeds:** Incluir la creación de este modelo en `priv/repo/seeds.exs`.

---

## 🟡 TAREAS DE ALTA PRIORIDAD

### T5. Tests del DecisionEngine y sus capas

**Archivos a crear (7 tests):**

| # | Archivo de test | Módulo testeado | ¿Necesita DB? | Complejidad |
|---|----------------|-----------------|---------------|-------------|
| 5.1 | `test/el_paso/domain/decision_engine/scorer_test.exs` | `Scorer` | No | Baja — tests puros de scoring |
| 5.2 | `test/el_paso/domain/decision_engine/decision_cache_test.exs` | `DecisionCache` | No | Baja — tests de ETS |
| 5.3 | `test/el_paso/domain/decision_engine/decision_engine_test.exs` | `DecisionEngine` (orquestador) | Sí | Media — fixtures de personalidades |
| 5.4 | `test/el_paso/domain/decision_engine/embedding_matcher_test.exs` | `EmbeddingMatcher` | Sí | Alta — necesita pgvector + embeddings |
| 5.5 | `test/el_paso/domain/decision_engine/llm_classifier_test.exs` | `LLMClassifier` | Sí | Alta — necesita modelo [classifier] o mock |
| 5.6 | `test/el_paso/domain/router_personality_test.exs` | `Router` (con DecisionEngine) | Sí | Media — integración Router+Engine |
| 5.7 | `test/el_paso/context/token_counter_test.exs` | `TokenCounter` | No | Baja — tests aritméticos |

**Estrategia de tests para el Scorer (5.1):**

```elixir
defmodule ElPaso.Domain.DecisionEngine.ScorerTest do
  use ExUnit.Case, async: true
  alias ElPaso.Domain.DecisionEngine.Scorer

  # Personalidades "mock" — maps con los campos que Scorer usa
  @coder %{
    name: "coder",
    trigger_keywords: ["code", "bug", "function"],
    regex_patterns: ["(?i)\\b(código|debug)\\b"],
    trigger_task_types: ["coding", "debugging"]
  }
  @translator %{
    name: "translator",
    trigger_keywords: ["translate", "to english", "traducir"],
    regex_patterns: ["(?i)\\b(traduc[ie]r?|to english)\\b"],
    trigger_task_types: ["translation"]
  }
  @general %{
    name: "general",
    trigger_keywords: ["hello", "help"],
    regex_patterns: [],
    trigger_task_types: []
  }

  describe "score/2" do
    test "detecta triggers multi-palabra (bigramas)" do
      result = Scorer.score([@coder, @translator, @general], "translate to english please")
      assert result.personality.name == "translator"
      assert result.confidence > 0.5
      assert result.trigger == "to english"
    end

    test "detecta mediante substring matching" do
      result = Scorer.score([@coder, @translator, @general], "necesito traducir este texto al inglés")
      assert result.personality.name == "translator"
    end

    test "usa regex patterns cuando no hay keyword match exacta" do
      result = Scorer.score([@coder, @translator, @general], "puedes traducirme esto?")
      assert result.personality.name == "translator"
    end

    test "devuelve confianza baja cuando nada matchea" do
      result = Scorer.score([@coder, @translator, @general], "blah blah xyzzz123")
      assert result.confidence < 0.3
    end

    test "incluye all_scores con nombres de personalidad" do
      result = Scorer.score([@coder, @translator], "debug this code")
      assert length(result.all_scores) == 2
      assert Enum.any?(result.all_scores, fn {name, _} -> name == "coder" end)
    end
  end
end
```

**Estrategia de tests para el DecisionEngine (5.3):**

Usar `ElPaso.DataCase` con `async: false` y fixtures que inserten personalidades en la BD (con y sin embeddings). Probar la cascada de capas:
- Caso 1: keyword match fuerte → debe devolver capa `:keyword` sin consultar embedding
- Caso 2: keyword match débil + embedding match fuerte → capa `:embedding`
- Caso 3: sin keyword ni embedding → capa `:default`
- Caso 4: cache hit → capa `:cache`

---

### T6. `mix elpaso personality embed` — ver T2 arriba

---

### T7. Actualizar `ESTADO_ACTUAL_V4.md` tras completar T1-T6

El documento de estado debe reflejar que el DecisionEngine ya es completamente funcional (no solo arquitectónicamente completo).

---

## 🟡 TAREAS DE PRIORIDAD MEDIA

### T8. Caché de system prompts (`prefix_manager.ex`)

**Archivo a crear:** `lib/el_paso/context/prefix_manager.ex`

**Situación actual:** Cada vez que se hace una inferencia, `run_anthropic_pipeline` en `server.ex` consulta la BD para obtener el system prompt de la personalidad. Esto es una query innecesaria por request.

**Qué hay que implementar:**

```elixir
defmodule ElPaso.Context.PrefixManager do
  @moduledoc """
  Caché en ETS de system prompts de personalidades.

  Evita consultar la BD en cada request para obtener el system_prompt,
  que rara vez cambia. Se invalida al modificar la personalidad.

  Tabla ETS: :personality_prefix_cache
  Estructura: {personality_name, system_prompt, cached_at}
  """

  @table :personality_prefix_cache
  @ttl_sec 600  # 10 minutos

  @spec get(String.t()) :: String.t() | nil
  def get(personality_name) do
    case :ets.lookup(@table, personality_name) do
      [{^personality_name, prompt, cached_at}] ->
        if System.monotonic_time(:second) - cached_at < @ttl_sec do
          prompt
        else
          :ets.delete(@table, personality_name)
          nil
        end
      [] -> nil
    end
  end

  @spec put(String.t(), String.t()) :: :ok
  def put(personality_name, system_prompt) do
    :ets.insert(@table, {personality_name, system_prompt, System.monotonic_time(:second)})
    :ok
  end

  @spec invalidate(String.t()) :: :ok
  def invalidate(personality_name) do
    :ets.delete(@table, personality_name)
    :ok
  end

  @spec init() :: :ets.tid()
  def init do
    case :ets.info(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
      _ -> @table
    end
  end
end
```

**Integración con `server.ex`:** En `run_anthropic_pipeline`, reemplazar la consulta a BD por:

```elixir
system_prompt = case PrefixManager.get(personality_name) do
  nil ->
    prompt = personality.system_prompt  # obtenido del DecisionEngine/Router
    PrefixManager.put(personality_name, prompt)
    prompt
  cached -> cached
end
```

**Invalidación:** Llamar a `PrefixManager.invalidate/1` desde `PersonalityManager.update_personality/2` al modificar el system_prompt.

---

### T9. Extraer `@task_categories` a configuración

**Archivo a modificar:** `lib/el_paso/domain/router/task_categories.ex`

**Situación actual:** Las categorías de tareas están hardcodeadas en el módulo:

```elixir
@task_categories [
  %{type: :coding, keywords: ["code", "function", "bug", ...]},
  %{type: :translation, keywords: ["translate", "traducir", ...]},
  ...
]
```

**Qué hay que hacer:**

1. Mover las categorías por defecto a `config/config.exs`:

```elixir
config :elpaso, :task_categories, [
  %{type: "coding", keywords: ["code", "function", "bug", "debug", "refactor", ...]},
  %{type: "translation", keywords: ["translate", "traducir", ...]},
  ...
]
```

2. Modificar `TaskCategories` para leer de `Application.get_env/2` con fallback a los defaults:

```elixir
defp categories do
  Application.get_env(:elpaso, :task_categories, @default_categories)
end
```

3. Documentar en `config/config.exs` cómo los usuarios pueden extenderlas.

---

### T10. Tests del SessionContext y ContextBuilder

**Archivos a crear:**

| Archivo | Módulo | ¿Necesita DB? |
|---------|--------|---------------|
| `test/el_paso/context/session_context_test.exs` | `SessionContext` | Sí (persistencia async) |
| `test/el_paso/context/context_builder_test.exs` | `ContextBuilder` | No |
| `test/el_paso/context/context_summarizer_test.exs` | `ContextSummarizer` | No (extractivo) |
| `test/el_paso/http/message_normalizer_test.exs` | `MessageNormalizer` | No |

**Puntos clave a testear en SessionContext:**
- `activate/2` registra el cambio de personalidad en el stack
- `deactivate/3` actualiza el shared_summary
- `get_context/2` devuelve el snapshot completo
- `record_message/4` mantiene la ventana deslizante en máximo 10 mensajes
- `put_knowledge/3` persiste en el knowledge_board

**Puntos clave a testear en ContextBuilder:**
- Respeta el token budget (25% system, 75% historial)
- Incluye el bloque de sesión compartida cuando hay summary
- La ventana deslizante no excede `@max_history_messages`
- No incluye el knowledge_board si está vacío

---

### T11. Tests del EmbeddingClient (mockeando Ollama)

**Archivo a crear:** `test/el_paso/context/embedding_client_test.exs`

**Estrategia:** Usar `Finch` para mockear las respuestas HTTP de Ollama. En `test_helper.exs` ya está configurado `Finch`:

```elixir
# En test_helper.exs (ya existente)
Finch.start_link(name: ElPaso.Finch)
```

**Mock de Ollama:**
```elixir
# En el test
setup do
  # Mockear POST a /api/embeddings
  FinchMock
  |> expect(:request, fn %{body: body}, _name, _opts ->
    {:ok, %{status: 200, body: Jason.encode!(%{embedding: List.duplicate(0.1, 768)})}}
  end)
  :ok
end
```

**Casos a testear:**
- `embed/1` con texto normal devuelve `{:ok, [float()]}`
- La caché ETS funciona (segunda llamada con mismo texto no llama a Ollama)
- El TTL de caché se respeta
- Fallback a OpenAI cuando Ollama falla (si `openai_api_key` está configurada)
- `health_check/0` verifica dimensiones correctas

---

### T12. Añadir `[classifier]` al modelo en seeds (ver T4)

---

## 🟢 TAREAS DE BAJA PRIORIDAD

### T13. Tests del Doctor

**Archivo a crear:** `test/el_paso/doctor_test.exs`

**Estrategia:** Testear que la función `config/0` devuelve los 11 checks con los campos esperados (`id`, `name`, `priority`, `check_fn`, `fix_fn`). Los checks individuales que dependen del sistema (Ollama, PostgreSQL) se testean solo si el entorno existe.

---

### T14. Tests del Bootstrap

**Archivo a crear:** `test/el_paso/bootstrap_test.exs`

**Estrategia:** Solo testear las funciones privadas exportables (o hacerlas `@doc false` para testearlas). El flujo completo de `run!/0` es difícil de testear porque interactúa con el sistema.

---

### T15. Tests del Secrets

**Archivo a crear:** `test/el_paso/security/secrets_test.exs`

Tests puros de crypto:
- `encrypt/1` + `decrypt/1` roundtrip
- `decrypt/1` con string corrupto devuelve `:error`
- `encrypt(nil)` → `nil`, `decrypt(nil)` → `{:ok, nil}`

---

## 🔮 MEJORAS POST-V4.0 (no urgentes)

### M1. `ContextSummarizer` abstractivo funcional

**Archivo:** `lib/el_paso/context/context_summarizer.ex`

La estrategia `:abstractive` (líneas ~75-85) está esqueletada pero funcional — depende de tener un modelo `[classifier]` configurado. Una vez que T4 esté completado, el summarizer abstractivo debería funcionar automáticamente.

**Validación pendiente:** Probar que el prompt de resumen cabe en el contexto del modelo clasificador (suele ser pequeño).

---

### M2. Migración fácil entre modelos de embeddings

**Situación:** La infraestructura soporta el cambio (`:vector` sin size fijo en la migración, `embedding_dims` configurable). Pero cambiar de `nomic-embed-text` (768-dim) a `bge-m3` (1024-dim) requiere regenerar todos los embeddings.

**Qué falta:** Un warning automático en Bootstrap si detecta que el modelo configurado no coincide con las dimensiones de los embeddings almacenados, y sugerir `mix elpaso personality embed`.

---

### M3. Streaming integrado con SessionContext

**Archivo:** `lib/el_paso/http/server.ex` (función `run_anthropic_stream`)

La función de streaming actual no pasa por `SessionContext` — no registra mensajes ni actualiza el shared_summary. Para integrarlo:

1. Extraer `session_id` del request (igual que en `run_anthropic_pipeline`)
2. Llamar a `SessionContext.activate/2` antes y `deactivate/3` después del stream
3. Acumular los chunks y, al terminar, llamar a `record_message/4`

---

### M4. Dashboard de routing en tiempo real

El módulo `ElPaso.HTTP.Dashboard` ya existe como un Plug.Router separado. Se puede extender con endpoints que muestren:

- Decisiones de routing recientes (de `routing_decisions` en BD y `:routing_decision_cache` en ETS)
- Sesiones activas (vía `Registry` de `SessionSupervisor`)
- Salud del sistema (integración con `Doctor`)

---

### M5. `bge-m3` como opción de un solo comando

Crear un comando `mix elpaso embeddings switch bge-m3` que:
1. Descargue el modelo vía `ollama pull bge-m3`
2. Actualice la config a 1024-dim
3. Regenerere todos los embeddings de personalidades
4. Muestre un diff de dimensiones antes/después

---

## 📊 RESUMEN DE ESFUERZO

| Categoría | Tareas | Esfuerzo estimado |
|-----------|--------|-------------------|
| 🔴 Bloqueante | 1 (Zaguan) | Depende del otro agente |
| 🔴 Críticas | 4 (T1-T4) | ~4-6 horas |
| 🟡 Alta prioridad | 3 (T5-T7) | ~6-8 horas |
| 🟡 Media prioridad | 5 (T8-T12) | ~5-7 horas |
| 🟢 Baja prioridad | 3 (T13-T15) | ~2-3 horas |
| 🔮 Post-v4.0 | 5 (M1-M5) | ~8-12 horas |
| **TOTAL** | **21 tareas** | **~25-36 horas** |

---

## 🎯 ORDEN DE ATAQUE RECOMENDADO

```
1. B1: Esperar/resolver Zaguan
       ↓
2. T1: Añadir embed_personality/1 y embed_all/0 a PersonalityManager
       ↓
3. T3: Crear seeds con 5 personalidades + embeddings
       ↓
4. T4: Añadir modelo [classifier] (en seeds)
       ↓
5. T2: Crear comando CLI `mix elpaso personality embed`
       ↓
6. T5.1, T5.2: Tests del Scorer y DecisionCache (puros, sin DB)
       ↓
7. T5.3, T5.6: Tests del DecisionEngine y Router (con DB)
       ↓
8. T10: Tests de SessionContext y ContextBuilder
       ↓
9. T8: PrefixManager (caché de system prompts)
       ↓
10. T9: Extraer task_categories a config
       ↓
11. T11-T15: Tests restantes
       ↓
12. T7: Actualizar ESTADO_ACTUAL_V4.md
```

---

*Documento generado por Macahan — Arquitecto Universal Supremo*
