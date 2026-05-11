#!/usr/bin/env elixir
# ──────────────────────────────────────────────────────────────────────────────
# ElPaso v4.0 — Seeds de desarrollo
# ──────────────────────────────────────────────────────────────────────────────
# Crea engines, modelos, y 5 personalidades con campos v4 (semantic_description,
# regex_patterns, min_confidence, cooldown_ms).
#
# Uso:
#   mix run priv/repo/seeds.exs
#
# Después de ejecutar los seeds, genera los embeddings:
#   elpaso personality embed
# ──────────────────────────────────────────────────────────────────────────────

alias ElPaso.Repo
alias ElPaso.Models.{Engine, Model, Personality}
alias ElPaso.Domain.{EngineManager, ModelManager, PersonalityManager}

IO.puts("\n🌱 ElPaso v4.0 — Seeds de desarrollo\n")

# ═══════════════════════════════════════════════════════════════════════════════
# 1. ENGINES
# ═══════════════════════════════════════════════════════════════════════════════

IO.puts("── Engines ──")

engines = [
  %{name: "ollama-local", adapter: "ollama", base_url: "http://localhost:11434/v1",
    description: "Ollama local (CPU/GPU)", config: %{keep_alive: "10m"}},
  %{name: "llama-server", adapter: "llama_cpp", base_url: "http://localhost:8081/v1",
    description: "llama.cpp server via localllama wrapper", config: %{timeout: 120_000}}
]

engines_map =
  Enum.reduce(engines, %{}, fn attrs, acc ->
    case Repo.get_by(Engine, name: attrs.name) do
      nil ->
        {:ok, engine} = EngineManager.create_engine(attrs)
        IO.puts("  ✓ engine: #{attrs.name} (#{attrs.adapter})")
        Map.put(acc, attrs.name, engine)

      existing ->
        IO.puts("  · engine: #{attrs.name} (ya existe)")
        Map.put(acc, attrs.name, existing)
    end
  end)

# ═══════════════════════════════════════════════════════════════════════════════
# 2. MODELS
# ═══════════════════════════════════════════════════════════════════════════════

IO.puts("\n── Modelos ──")

ollama = engines_map["ollama-local"]
llama_srv = engines_map["llama-server"]

models = [
  # ── Clasificador del DecisionEngine (capa 3) ──
  # El tag "[classifier]" en description es LO QUE ACTIVA la capa 3.
  # La personalidad que lo use tendrá prioridad MÁXIMA para no ser evictada.
  %{name: "phi4-mini", engine: ollama,
    url: "http://localhost:11434/v1",
    description: "Microsoft Phi-4-mini [classifier] — modelo ligero para clasificación de intenciones del DecisionEngine",
    max_tokens: 512, temperature: 0.3, ram_mb: 2500, vram_mb: 2800,
    cold_start_estimate_ms: 8000},

  # ── Modelos de trabajo ──
  %{name: "gemma3", engine: ollama,
    url: "http://localhost:11434/v1",
    description: "Google Gemma 3 — modelo rápido y versátil para tareas generales",
    max_tokens: 4096, temperature: 0.7, ram_mb: 4000, vram_mb: 5000},

  %{name: "qwen2.5-coder", engine: ollama,
    url: "http://localhost:11434/v1",
    description: "Qwen 2.5 Coder — especializado en generación y análisis de código",
    max_tokens: 8192, temperature: 0.3, ram_mb: 4500, vram_mb: 6000},

  %{name: "llama3.2", engine: ollama,
    url: "http://localhost:11434/v1",
    description: "Meta Llama 3.2 — balance rendimiento/calidad, multiidioma",
    max_tokens: 4096, temperature: 0.7, ram_mb: 3000, vram_mb: 3500}
]

models_map =
  Enum.reduce(models, %{}, fn %{name: name} = attrs, acc ->
    case Repo.get_by(Model, name: name) do
      nil ->
        {:ok, model} = ModelManager.create_model(Map.delete(attrs, :name) |> Map.put(:name, name))
        IO.puts("  ✓ model: #{name}")
        Map.put(acc, name, model)

      existing ->
        IO.puts("  · model: #{name} (ya existe)")
        Map.put(acc, name, existing)
    end
  end)

# ═══════════════════════════════════════════════════════════════════════════════
# 3. PERSONALITIES (v4.0 — todos los campos del DecisionEngine)
# ═══════════════════════════════════════════════════════════════════════════════

IO.puts("\n── Personalidades ──")

# Nota: los embeddings se generan DESPUÉS con `elpaso personality embed`.
#       Si Ollama no está corriendo, igual puedes crear las personalidades.

personalities = [
  # ─── PERSONALIDAD 0: classifier-router (prioridad MÁXIMA) ───
  %{name: "classifier-router",
    description: "Clasificador de intenciones del DecisionEngine — NUNCA desactivar",
    system_prompt: """
    Eres un clasificador de intenciones. Tu tarea es decidir qué especialista
    debe atender la siguiente consulta del usuario.

    Responde ÚNICAMENTE con el nombre de la personalidad más adecuada de esta lista:
    - coder: programación, debugging, algoritmos, código
    - architect: arquitectura de sistemas, diseño, patrones, escalabilidad
    - translator: traducción entre idiomas, localización
    - general: conversación general, preguntas, ayuda

    NO expliques tu decisión. SOLO devuelve el nombre.
    """,
    semantic_description: "Router classifier that decides which specialist personality should handle user requests based on intent analysis. Capable of distinguishing between programming, architecture design, language translation, and general conversation tasks. Uses short context windows and deterministic output for fast routing decisions.",
    trigger_keywords: ["classify", "route", "classifier"],
    trigger_task_types: ["classification"],
    regex_patterns: [],
    priority: 999,
    is_default: false,
    min_confidence: 0.0,
    cooldown_ms: 0,
    active: true,
    model: models_map["phi4-mini"],
    engine: ollama,
    config: %{max_tokens: 128, temperature: 0.1}},

  # ─── PERSONALIDAD 1: coder ───
  %{name: "coder",
    description: "Experto en programación, debugging y análisis de código",
    system_prompt: """
    Eres un programador senior experto. Tu rol es ayudar con código, debugging,
    algoritmos, revisión de código y explicación de conceptos de programación.

    Reglas:
    - Escribe código limpio, documentado y con manejo de errores
    - Usa las mejores prácticas del lenguaje/framework
    - Explica el POR QUÉ de cada decisión técnica
    - Prefiere patrones probados sobre soluciones clever
    - Si no sabes algo con certeza, dilo explícitamente
    """,
    semantic_description: "Expert programmer specialized in code generation, debugging, algorithm analysis, code review, and software engineering concepts. Proficient in multiple programming languages including Elixir, Python, Rust, TypeScript, Go, and C. Focuses on clean architecture, error handling, testing, and production-ready patterns. Avoids clever hacks in favor of maintainable solutions. Capable of explaining complex CS concepts and making architecture decisions with tradeoff analysis.",
    trigger_keywords: ["code", "programming", "debug", "function", "algorithm", "bug",
      "compile", "error", "type", "test", "refactor", "api", "endpoint",
      "database", "query", "sql", "module", "class", "import", "package",
      "programar", "programación", "código", "codigo", "depurar", "función",
      "funcion", "algoritmo", "error", "compilar", "refactorizar", "test"],
    trigger_task_types: ["code", "debugging", "refactoring"],
    regex_patterns: [
      # Patrones de código
      "(?i)\\b(write|fix|debug|refactor|implement|compile|deploy)\\b.*\\b(code|function|class|module|api|endpoint|test|bug)\\b",
      "(?i)\\b(escrib[ie]|arregl[ae]|depur[ae]|implement[ae]|compil[ae]|refactoriz[ae])\\b.*\\b(c[oó]digo|funci[oó]n|clase|m[oó]dulo|api|error|test)\\b",
      # Extensiones de archivo comunes
      "\\b\\.(ex|exs|py|rs|js|ts|go|java|rb|cpp|c|hs|sql)\\b"
    ],
    priority: 80,
    is_default: false,
    min_confidence: 0.30,
    cooldown_ms: 2000,
    active: true,
    model: models_map["qwen2.5-coder"],
    engine: ollama,
    config: %{temperature: 0.3, max_tokens: 8192}},

  # ─── PERSONALIDAD 2: architect ───
  %{name: "architect",
    description: "Arquitecto de sistemas — diseño, patrones, escalabilidad",
    system_prompt: """
    Eres un arquitecto de software senior. Tu especialidad es el diseño de sistemas,
    patrones de arquitectura, decisiones de escalabilidad y trade-offs técnicos.

    Reglas:
    - Analiza el problema completo antes de proponer soluciones
    - Presenta trade-offs (pros/cons) para cada opción
    - Considera: escalabilidad, mantenibilidad, coste, complejidad
    - Usa diagramas conceptuales (en texto) cuando ayuden
    - Basa tus recomendaciones en patrones conocidos (C4, ADR, DDD, CQRS)
    """,
    semantic_description: "Senior software architect specialized in system design, architectural patterns, scalability decisions, and technical tradeoff analysis. Expert in distributed systems, microservices, event-driven architecture, CQRS/ES, domain-driven design (DDD), and cloud-native patterns. Analyzes problems holistically considering cost, complexity, maintainability, and team capabilities. Uses ADRs (Architecture Decision Records) format for recommendations. Fluent in C4 model diagrams and system decomposition strategies.",
    trigger_keywords: ["architecture", "design", "system", "pattern", "scale",
      "microservice", "distributed", "cqrs", "event", "domain",
      "cloud", "deploy", "pipeline", "ci/cd", "kubernetes", "docker",
      "database schema", "data model", "tradeoff", "decision",
      "arquitectura", "diseño", "diseño de sistema", "sistema", "patrón",
      "patron", "escalar", "microservicio", "distribuido", "evento",
      "dominio", "nube", "despliegue", "tubería", "modelo de datos"],
    trigger_task_types: ["architecture", "design", "system_design"],
    regex_patterns: [
      "(?i)\\b(design|architect|scale|system)\\b.*\\b(pattern|decision|tradeoff|strategy)\\b",
      "(?i)\\b(diseñ[ao]|arquitect[au]|escal[ae]|sistema)\\b.*\\b(patr[oó]n|decisi[oó]n|estrategia)\\b",
      "(?i)\\bhow (would|should|to) (design|architect|structure|scale)\\b",
      "(?i)\\b(microservices?|monolith|serverless|event.sourcing|cqrs|event.driven)\\b"
    ],
    priority: 60,
    is_default: false,
    min_confidence: 0.30,
    cooldown_ms: 2000,
    active: true,
    model: models_map["llama3.2"],
    engine: ollama,
    config: %{temperature: 0.5, max_tokens: 4096}},

  # ─── PERSONALIDAD 3: translator ───
  %{name: "translator",
    description: "Traductor multiidioma — español, inglés, francés, alemán...",
    system_prompt: """
    Eres un traductor profesional. Tu especialidad es traducir texto entre idiomas
    manteniendo el tono, contexto y matices del original.

    Reglas:
    - Detecta automáticamente el idioma de origen si no se especifica
    - Preserva el tono (formal, informal, técnico, coloquial)
    - Adapta modismos y referencias culturales al idioma destino
    - Si el texto es ambiguo, pregunta antes de traducir
    - Para documentos técnicos, mantén la terminología precisa
    """,
    semantic_description: "Professional multilingual translator specialized in translating text between languages while preserving tone, context, and cultural nuances. Supports Spanish, English, French, German, Italian, Portuguese, and Japanese. Automatically detects source language when not specified. Capable of handling technical documentation, literary text, casual conversation, and business correspondence. Adapts idioms and cultural references appropriately for the target language. Maintains consistent terminology in technical translations.",
    trigger_keywords: ["translate", "translation", "traducir", "traducción",
      "traduccion", "english", "español", "spanish", "french", "français",
      "francés", "frances", "german", "deutsch", "alemán", "aleman",
      "italian", "italiano", "portuguese", "portugués", "portugues",
      "japanese", "japonés", "japones", "language", "idioma", "lengua",
      "to english", "to spanish", "a español", "a inglés", "a ingles",
      "en español", "en inglés", "en ingles", "in english", "in spanish"],
    trigger_task_types: ["translation", "localization"],
    regex_patterns: [
      "(?i)\\b(translate|traduc[ei])\\b.*\\b(to|from|a|al|del|into|en|in)\\b",
      "(?i)\\b(in|en|to|a)\\b\\s+(english|español|spanish|french|francés|german|alemán)\\b",
      "(?i)\\bhow (do you|to) say\\b",
      "(?i)\\bwhat does .+ mean in (english|spanish|español|inglés)\\b",
      "(?i)\\b(inglés|inglés|español|spanish|english)\\s+(por favor|please)\\b"
    ],
    priority: 40,
    is_default: false,
    min_confidence: 0.30,
    cooldown_ms: 1000,
    active: true,
    model: models_map["llama3.2"],
    engine: ollama,
    config: %{temperature: 0.4, max_tokens: 2048}},

  # ─── PERSONALIDAD 4: general (default) ───
  %{name: "general",
    description: "Asistente general — conversación, preguntas, ayuda variada (fallback)",
    system_prompt: """
    Eres un asistente de IA general útil, conversacional y conocedor.
    Puedes ayudar con una amplia variedad de temas: preguntas, explicaciones,
    brainstorming, escritura, análisis, etc.

    Reglas:
    - Sé conversacional pero directo
    - Si no sabes algo, admítelo en lugar de inventar
    - Adapta tu tono al contexto del usuario
    - Para temas especializados (código, arquitectura, traducción), sugiere
      cambiar a la personalidad adecuada
    """,
    semantic_description: "General-purpose AI assistant capable of handling a wide variety of tasks including conversation, questions, explanations, brainstorming, writing assistance, analysis, summaries, and creative tasks. Serves as the default fallback personality when no specialist matches. Adapts tone to user context. When specialized help is needed (coding, architecture, translation), suggests switching to the appropriate specialist personality. Friendly, direct, and honest about limitations.",
    trigger_keywords: ["help", "hello", "hi", "hey", "question", "explain",
      "what", "how", "why", "who", "when", "where",
      "summarize", "summary", "write", "brainstorm", "idea",
      "ayuda", "hola", "pregunta", "explica", "explicar",
      "qué", "como", "cómo", "por qué", "porque", "quién",
      "quien", "cuándo", "cuando", "dónde", "donde",
      "resumir", "resumen", "escribir", "idea"],
    trigger_task_types: ["general", "question_answer", "summarization", "creative"],
    regex_patterns: [],
    priority: 1,
    is_default: true,
    min_confidence: 0.0,
    cooldown_ms: 0,
    active: true,
    model: models_map["gemma3"],
    engine: ollama,
    config: %{temperature: 0.7, max_tokens: 4096}}
]

personalities_created =
  Enum.reduce(personalities, 0, fn personality_attrs, acc ->
    name = personality_attrs.name
    model = personality_attrs.model
    engine = personality_attrs.engine

    case Repo.get_by(Personality, name: name) do
      nil ->
        attrs = personality_attrs
                |> Map.delete(:model)
                |> Map.delete(:engine)
                |> Map.put(:model_id, model && model.id)
                |> Map.put(:engine_id, engine && engine.id)

        case PersonalityManager.create_personality(attrs) do
          {:ok, p} ->
            default_tag = if p.is_default, do: " ★default", else: ""
            IO.puts("  ✓ personality: #{p.name} (prio:#{p.priority}#{default_tag})")
            acc + 1

          {:error, changeset} ->
            IO.puts("  ✗ #{name}: #{inspect(changeset.errors)}")
            acc
        end

      existing ->
        default_tag = if existing.is_default, do: " ★default", else: ""
        IO.puts("  · personality: #{name} (ya existe, prio:#{existing.priority}#{default_tag})")
        acc
    end
  end)

# ═══════════════════════════════════════════════════════════════════════════════
# 4. RESUMEN
# ═══════════════════════════════════════════════════════════════════════════════

IO.puts("""

══════════════════════════════════════════════════════════
  ✅ Seeds completados!

  Engines:    #{map_size(engines_map)}
  Modelos:    #{map_size(models_map)}
  Personalidades: #{personalities_created} creadas

  ── Siguientes pasos ──

  1. Generar embeddings (requiere Ollama corriendo):
     elpaso personality embed

  2. Verificar el DecisionEngine:
     iex -S mix

     # Capa 1 (keywords): siempre funciona
     ElPaso.Domain.DecisionEngine.decide([%{role: "user", content: "escribe una función"}])

     # Capa 2 (embedding): requiere embeddings generados
     ElPaso.Domain.DecisionEngine.decide([%{role: "user", content: "how would you build a distributed cache?"}])

  3. Arrancar el servidor:
     elpaso server start

  4. Probar con curl:
     curl -X POST http://localhost:4000/v1/chat/completions \\
       -H "Content-Type: application/json" \\
       -d '{"messages":[{"role":"user","content":"translate to spanish: hello world"}], "personality":"auto"}'

══════════════════════════════════════════════════════════
""")
