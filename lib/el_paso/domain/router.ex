defmodule ElPaso.Domain.Router do
  @moduledoc """
  Router de modelos para tomar decisiones sobre qué modelo usar para una solicitud.

  Este módulo implementa la lógica de enrutamiento basada en:
  - Task affinity (configuración por tipo de tarea)
  - Disponibilidad de modelos activos
  - Rendimiento histórico
  """

  alias ElPaso.Domain.ModelManager
  alias ElPaso.Context.Storage

  @doc """
  Selecciona el modelo óptimo para una solicitud basada en task affinity.

  Selección por affinity score: weighted_score = task_affinity * complexity_ceiling.

  Si no hay task_affinity configurado, selecciona el primer modelo activo disponible.
  """
  @spec select_model(list(), map()) :: {:ok, map()} | {:error, any()}
  def select_model(messages, _options) do
    # Detect task type from message content
    task_type = detect_task_type(messages)

    # Get all active models
    active_models =
      ModelManager.list_models()
      |> Enum.filter(& &1.active)

    if active_models == [] do
      {:error, :no_active_model}
    else
      # Score each model by affinity for the detected task type
      scored =
        Enum.map(active_models, fn model ->
          affinity = get_task_affinity(model, task_type)
          ceiling = model.complexity_ceiling || 1.0
          score = affinity * ceiling

          {score, model}
        end)
        |> Enum.sort_by(fn {score, _} -> score end, :desc)

      {best_score, best_model} = List.first(scored)

      {:ok,
       %{
         model_name: best_model.name,
         engine_id: best_model.engine_id,
         decision_reason: "affinity:#{task_type}",
         task_type: task_type,
         score: best_score,
         timestamp: DateTime.utc_now()
       }}
    end
  end

  # Get affinity for a specific task type from model's task_affinity config
  defp get_task_affinity(model, task_type) do
    case model.task_affinity do
      %{^task_type => affinity} when is_number(affinity) ->
        affinity

      %{default: default_affinity} when is_number(default_affinity) ->
        default_affinity

      _ ->
        # Default affinity when not configured: 0.5
        0.5
    end
  end

  # Detect task type from message content using keyword scoring
  defp detect_task_type(messages) do
    content =
      messages
      |> Enum.map(fn
        %{"content" => c} -> c
        %{content: c} -> c
        _ -> ""
      end)
      |> Enum.join(" ")
      |> String.downcase()

    # ── Keyword scoring ─────────────────────────────────────────
    # Cada categoría tiene keywords con pesos.
    # Se suma el peso de cada keyword encontrada y se elige la categoría
    # con mayor puntuación. Si ninguna supera el umbral, :unknown.

    categories = %{
      code: %{
        weight: 0,
        keywords: %{
          # Alta señal
          "function" => 4,
          "implement" => 4,
          "algorithm" => 4,
          "class" => 3,
          "method" => 3,
          "api" => 3,
          "endpoint" => 3,
          "bug" => 3,
          "error" => 3,
          "compile" => 3,
          "test" => 3,
          "debug" => 3,
          "refactor" => 3,
          "library" => 3,
          "framework" => 3,
          # Media señal
          "code" => 2,
          "program" => 2,
          "script" => 2,
          "module" => 2,
          "package" => 2,
          "import" => 2,
          "export" => 2,
          "return" => 2,
          "variable" => 2,
          "array" => 2,
          "string" => 2,
          "integer" => 2,
          "interface" => 2,
          "abstract" => 2,
          "docker" => 2,
          "sql" => 2,
          "query" => 2,
          "database" => 2,
          "schema" => 2,
          "migration" => 2,
          "html" => 2,
          "css" => 2,
          "javascript" => 2,
          "python" => 2,
          "elixir" => 2,
          "rust" => 2,
          "typescript" => 2,
          # Baja señal
          "file" => 1,
          "data" => 1,
          "type" => 1,
          "object" => 1,
          "server" => 1,
          "client" => 1,
          "request" => 1,
          "response" => 1
        }
      },
      translation: %{
        weight: 0,
        keywords: %{
          "translate" => 5,
          "translation" => 5,
          "traduce" => 5,
          "traducción" => 5,
          "traducir" => 5,
          "language" => 2,
          "idioma" => 2,
          "lengua" => 2,
          "spanish" => 3,
          "english" => 3,
          "french" => 3,
          "español" => 3,
          "inglés" => 3,
          "francés" => 3,
          "german" => 3,
          "chinese" => 3,
          "japanese" => 3,
          "alemán" => 3,
          "chino" => 3,
          "japonés" => 3,
          "to english" => 4,
          "to spanish" => 4,
          "en español" => 4
        }
      },
      summarization: %{
        weight: 0,
        keywords: %{
          "summarize" => 5,
          "summary" => 5,
          "summarization" => 5,
          "resumen" => 5,
          "resumir" => 5,
          "resume" => 4,
          "resum" => 4,
          "tl;dr" => 5,
          "tldr" => 5,
          "key points" => 3,
          "main idea" => 3,
          "brief" => 2,
          "concise" => 2,
          "sum up" => 4,
          "recap" => 4,
          "bullet points" => 3,
          "abstract" => 2
        }
      },
      reasoning: %{
        weight: 0,
        keywords: %{
          "analyze" => 4,
          "analysis" => 4,
          "analizar" => 4,
          "análisis" => 4,
          "compare" => 4,
          "comparison" => 4,
          "comparar" => 4,
          "comparación" => 4,
          "evaluate" => 4,
          "evaluation" => 4,
          "evaluar" => 4,
          "pros and cons" => 4,
          "advantages" => 3,
          "disadvantages" => 3,
          "ventajas" => 3,
          "desventajas" => 3,
          "reason" => 3,
          "razón" => 3,
          "por qué" => 3,
          "why" => 3,
          "cause" => 3,
          "effect" => 3,
          "consequence" => 3,
          "difference between" => 4,
          "diferencia entre" => 4,
          "better" => 2,
          "worse" => 2,
          "mejor" => 2,
          "peor" => 2,
          "opinion" => 2,
          "opinar" => 2,
          "think" => 2,
          "crees" => 2,
          "critique" => 4,
          "review" => 3,
          "criticar" => 4,
          "reseña" => 3
        }
      },
      question_answer: %{
        weight: 0,
        keywords: %{
          "what is" => 4,
          "what are" => 4,
          "qué es" => 4,
          "qué son" => 4,
          "define" => 4,
          "definition" => 4,
          "definir" => 4,
          "definición" => 4,
          "explain" => 3,
          "explicar" => 3,
          "explica" => 3,
          "explique" => 3,
          "describe" => 3,
          "describir" => 3,
          "how does" => 4,
          "cómo funciona" => 4,
          "how to" => 3,
          "who is" => 3,
          "when was" => 3,
          "where is" => 3,
          "qué significa" => 4,
          "cuál es" => 3,
          "por qué" => 2,
          "meaning of" => 4,
          "significado de" => 4,
          "history of" => 3,
          "historia de" => 3,
          "example" => 2,
          "ejemplo" => 2
        }
      },
      creative: %{
        weight: 0,
        keywords: %{
          "write a story" => 5,
          "write a poem" => 5,
          "escribe un cuento" => 5,
          "creative" => 4,
          "creativo" => 4,
          "imagination" => 3,
          "story" => 3,
          "poem" => 3,
          "poetry" => 3,
          "cuento" => 3,
          "poema" => 3,
          "fiction" => 3,
          "novel" => 2,
          "character" => 2,
          "roleplay" => 4,
          "act as" => 4,
          "pretend" => 3,
          "joke" => 3,
          "riddle" => 3,
          "chiste" => 3,
          "adivinanza" => 3,
          "song" => 3,
          "lyrics" => 3,
          "canción" => 3,
          "letra" => 3,
          "brainstorm" => 3,
          "ideas for" => 3,
          "ideas para" => 3
        }
      }
    }

    # Calcular puntuación para cada categoría
    scored =
      Enum.map(categories, fn {cat, %{keywords: kws}} ->
        score =
          Enum.reduce(kws, 0, fn {keyword, weight}, acc ->
            if String.contains?(content, keyword), do: acc + weight, else: acc
          end)

        {cat, score}
      end)

    # Elegir la categoría con mayor puntuación, con umbral mínimo de 4
    case Enum.max_by(scored, fn {_, score} -> score end, fn -> {:unknown, 0} end) do
      {cat, score} when score >= 4 -> cat
      _ -> :unknown
    end
  end

  @doc """
  Obtiene el estado actual del modelo.

  ## Parámetros

  - `model_name` - Nombre del modelo

  ## Ejemplo

      iex> Router.get_model_state("gpt-4")
  """
  @spec get_model_state(String.t()) :: {:ok, map()} | {:error, any()}
  def get_model_state(model_name) do
    case ModelManager.get_model(model_name) do
      nil ->
        {:error, :model_not_found}

      model ->
        {:ok,
         %{
           name: model.name,
           status: if(model.active, do: "active", else: "inactive"),
           availability: if(model.active, do: true, else: false),
           performance: %{},
           cost_per_token: nil
         }}
    end
  end

  @doc """
  Obtiene la configuración de enrutamiento para un modelo.

  ## Parámetros

  - `model_name` - Nombre del modelo

  ## Ejemplo

      iex> Router.get_routing_config("gpt-4")
  """
  @spec get_routing_config(String.t()) :: {:ok, map()} | {:error, any()}
  def get_routing_config(model_name) do
    case ModelManager.get_model(model_name) do
      nil ->
        {:error, :model_not_found}

      model ->
        {:ok,
         %{
           task_affinity: model.task_affinity || %{},
           complexity_ceiling: model.complexity_ceiling,
           cold_start_estimate_ms: model.cold_start_estimate_ms
         }}
    end
  end

  @doc """
  Actualiza el resultado de una decisión de enrutamiento.

  ## Parámetros

  - `request_id` - ID del request
  - `routing_decision` - Decisión de enrutamiento

  ## Ejemplo

      iex> Router.update_routing_outcome("req123", %{model_name: "gpt-4", response_time: 150})
  """
  @spec update_routing_outcome(String.t(), map()) :: :ok | {:error, any()}
  def update_routing_outcome(request_id, routing_decision) do
    # Extract outcome and latency from the routing decision
    outcome = Map.get(routing_decision, :outcome, "completed")
    latency_ms = Map.get(routing_decision, :response_time, 0)

    case Storage.update_routing_outcome(request_id, outcome, latency_ms) do
      {1, _} ->
        :ok

      {0, _} ->
        {:error, :not_found}
    end
  end
end
