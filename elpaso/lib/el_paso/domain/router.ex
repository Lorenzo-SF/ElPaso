defmodule ElPaso.Domain.Router do
  @moduledoc """
  Motor de enrutamiento heurístico para decisiones de modelo.
  
  Este módulo decide qué modelo debe atender cada request basándose en múltiples dimensiones:
  características del request, estado del sistema y preferencias de la sesión.
  """

  alias ElPaso.Domain.ModelManager
  alias ElPaso.Context.Storage
  alias ElPaso.HTTP.RequestParser

  # Estructura para el vector de características
  defmodule FeatureVector do
    @moduledoc """
    Estructura que representa las características extraídas del prompt.
    """

    defstruct [
      :token_estimate,
      :task_type,
      :complexity_score,
      :language,
      :has_structured_output_request,
      :is_continuation,
      :prompt_length_chars
    ]

    @type t :: %FeatureVector{
            token_estimate: non_neg_integer(),
            task_type: :code | :reasoning | :summarization | :question_answer |
                      :creative | :translation | :unknown,
            complexity_score: float(),
            language: String.t(),
            has_structured_output_request: boolean(),
            is_continuation: boolean(),
            prompt_length_chars: non_neg_integer()
          }
  end

  # Estructura para el estado del modelo
  defmodule ModelState do
    @moduledoc """
    Estructura que representa el estado actual de un modelo.
    """

    defstruct [
      :model_id,
      :status,
      :current_queue_depth,
      :avg_latency_ms,
      :last_error_at,
      :consecutive_errors,
      :ram_mb
    ]

    @type t :: %ModelState{
            model_id: String.t(),
            status: :hot | :warming | :cold | :error | :disabled,
            current_queue_depth: non_neg_integer(),
            avg_latency_ms: non_neg_integer(),
            last_error_at: DateTime.t() | nil,
            consecutive_errors: non_neg_integer(),
            ram_mb: non_neg_integer()
          }
  end

  # Estructura para la decisión de enrutamiento
  defmodule RoutingDecision do
    @moduledoc """
    Estructura que representa una decisión de enrutamiento registrada.
    """

    defstruct [
      :request_id,
      :session_id,
      :selected_model,
      :runner_up,
      :features,
      :scores,
      :reason,
      :decided_at,
      :decision_latency_us
    ]

    @type t :: %RoutingDecision{
            request_id: String.t(),
            session_id: String.t(),
            selected_model: String.t(),
            runner_up: String.t() | nil,
            features: FeatureVector.t(),
            scores: %{String.t() => float()},
            reason: String.t(),
            decided_at: DateTime.t(),
            decision_latency_us: non_neg_integer()
          }
  end

  @doc """
  Punto de entrada principal: recibe el request y devuelve el model_id seleccionado.
  """
  def route(request_id, session_id, user_message, overrides \\ %{}) do
    # Extraer características del prompt (feature extraction)
    features = extract_features(user_message)

    # Si hay force_model en overrides, usar ese modelo directamente
    if overrides.force_model do
      decision = %RoutingDecision{
        request_id: request_id,
        session_id: session_id,
        selected_model: overrides.force_model,
        features: features,
        scores: %{},
        reason: "force_model override by client",
        decided_at: DateTime.utc_now(),
        decision_latency_us: 0
      }
      
      {:ok, overrides.force_model, decision}
    else
      # Consultar estado del sistema
      model_states = ModelManager.all_states()

      # Calcular scores para cada modelo
      scores = calculate_scores(model_states, features)

      # Seleccionar el mejor modelo
      selected_model = select_best_model(scores)

      # Registrar la decisión de enrutamiento
      decision = %RoutingDecision{
        request_id: request_id,
        session_id: session_id,
        selected_model: selected_model,
        features: features,
        scores: scores,
        reason: "best fit for #{features.task_type} task",
        decided_at: DateTime.utc_now(),
        decision_latency_us: 0
      }

      # Guardar la decisión en Storage
      Storage.save_routing_decision(decision)

      {:ok, selected_model, decision}
    end
  end

  @doc """
  Notifica al router el resultado de una inferencia completada o fallida.
  """
  def record_outcome(request_id, outcome, latency_ms) do
    # Actualizar estadísticas internas del modelo
    case Storage.update_routing_outcome(request_id, outcome, latency_ms) do
      :ok ->
        # Actualizar ModelState en ModelManager
        ModelManager.record_call_result(request_id, latency_ms, outcome)
      error -> error
    end
  end

  @doc """
  Devuelve las últimas N decisiones de routing para diagnóstico.
  """
  def recent_decisions(limit \\ 50) do
    # Implementación simplificada - en producción se usaría Storage
    []
  end

  @doc """
  Devuelve las estadísticas de routing agrupadas por task_type y model_id.
  """
  def stats() do
    # Implementación simplificada - en producción se usaría Storage
    %{}
  end

  # Funciones auxiliares para el feature extraction
  defp extract_features(user_message) do
    # Extraer características del mensaje
    
    # Estimar tokens
    token_estimate = estimate_tokens(user_message)
    
    # Detectar tipo de tarea
    task_type = detect_task_type(user_message)
    
    # Calcular complejidad
    complexity_score = calculate_complexity_score(user_message, task_type)
    
    # Detectar idioma
    language = detect_language(user_message)
    
    # Verificar si tiene solicitud de salida estructurada
    has_structured_output_request = has_structured_output(user_message)
    
    # Verificar si es continuación
    is_continuation = false
    
    # Longitud del mensaje
    prompt_length_chars = String.length(user_message)

    %FeatureVector{
      token_estimate: token_estimate,
      task_type: task_type,
      complexity_score: complexity_score,
      language: language,
      has_structured_output_request: has_structured_output_request,
      is_continuation: is_continuation,
      prompt_length_chars: prompt_length_chars
    }
  end

  # Funciones auxiliares para el scoring
  defp calculate_scores(model_states, features) do
    # Calcular scores para cada modelo basado en las características y estado del sistema
    
    scores = %{}
    
    Enum.reduce(model_states, scores, fn model_state, acc ->
      score = calculate_model_score(model_state, features)
      Map.put(acc, model_state.model_id, score)
    end)
  end

  defp calculate_model_score(model_state, features) do
    # Calcular score para un modelo específico
    
    # Base score basado en afinidad de tarea
    base_score = fit_score(model_state, features)
    
    # Penalización por cold start
    cold_start_penalty = cold_start_penalty(model_state, features)
    
    # Penalización por cola
    queue_penalty = queue_penalty(model_state)
    
    # Penalización por errores
    error_penalty = error_penalty(model_state)
    
    # Calcular score final
    final_score = base_score - cold_start_penalty - queue_penalty - error_penalty
    
    final_score
  end

  defp fit_score(model_state, features) do
    # Calcular afinidad del modelo para la tarea
    task_affinity = Map.get(model_state.routing_config, :task_affinity, %{})
    affinity = Map.get(task_affinity, features.task_type, 0.5)
    
    # Calcular complejidad penalizadora
    complexity_penalizer = max(0, features.complexity_score - model_state.complexity_ceiling) * 0.5
    
    affinity * (1.0 - complexity_penalizer)
  end

  defp cold_start_penalty(model_state, features) do
    # Penalización por tiempo de arranque frío
    if model_state.status == :cold do
      min(1.0, model_state.cold_start_estimate_ms / 5000) * 1.5
    else
      0.0
    end
  end

  defp queue_penalty(model_state) do
    # Penalización lineal por cola de requests
    model_state.current_queue_depth * 0.05
  end

  defp error_penalty(model_state) do
    # Penalización por errores consecutivos
    if model_state.consecutive_errors >= 3 do
      :infinity
    else
      model_state.consecutive_errors * 0.15
    end
  end

  # Funciones auxiliares para selección
  defp select_best_model(scores) do
    # Seleccionar el modelo con mayor score
    case Enum.max_by(scores, fn {_model_id, score} -> score end) do
      {model_id, _score} -> model_id
      nil -> "default"
    end
  end

  # Funciones de detección de características
  defp estimate_tokens(content) do
    # Estimación simple basada en caracteres (3 caracteres ≈ 1 token)
    div(String.length(content), 3)
  end

  defp detect_task_type(content) do
    # Detección heurística del tipo de tarea
    
    content_lower = String.downcase(content)
    
    cond do
      String.contains?(content_lower, ["code", "function", "implement", "debug", "script"]) ->
        :code
      String.contains?(content_lower, ["explain", "reason", "analyze", "compare"]) ->
        :reasoning
      String.contains?(content_lower, ["summarize", "synthesize", "tl;dr", "puntos clave"]) ->
        :summarization
      String.contains?(content_lower, ["what is", "when", "who", "define"]) ->
        :question_answer
      String.contains?(content_lower, ["write", "create", "invent", "story", "poem"]) ->
        :creative
      String.contains?(content_lower, ["translate", "in english", "en español"]) ->
        :translation
      true ->
        :unknown
    end
  end

  defp calculate_complexity_score(content, task_type) do
    # Calcular complejidad basada en múltiples señales
    
    # Token estimate
    token_estimate = estimate_tokens(content)
    
    # Task affinity weight (simplificado)
    task_affinity_weight = case task_type do
      :code -> 0.8
      :reasoning -> 0.9
      :summarization -> 0.6
      :question_answer -> 0.3
      :creative -> 0.7
      :translation -> 0.4
      :unknown -> 0.5
    end
    
    # Sentence depth (simplificado)
    sentence_depth = String.split(content, ~r/[.!?]+/ |> Enum.filter(fn s -> s != "" end)) |> length()
    
    # Vocabulary density (simplificado)
    words = String.split(content, ~r/\s+/) |> Enum.filter(fn w -> w != "" end)
    unique_words = Enum.uniq(words) |> length()
    vocabulary_density = unique_words / max(length(words), 1)
    
    # Question count
    question_count = Enum.count(String.split(content, "¿")) + Enum.count(String.split(content, "?"))
    
    # Combinar todas las señales
    complexity_score =
      0.30 * (token_estimate / 100) +
      0.25 * task_affinity_weight +
      0.20 * (sentence_depth / 10) +
      0.15 * vocabulary_density +
      0.10 * (question_count / 5)
    
    # Limitar entre 0 y 1
    :erlang.float(max(0, min(1, complexity_score)))
  end

  defp detect_language(content) do
    # Detectar idioma (simplificado - en producción se usaría bibliotecas especializadas)
    "en"
  end

  defp has_structured_output(content) do
    # Verificar si el mensaje tiene solicitud de salida estructurada
    
    content_lower = String.downcase(content)
    
    String.contains?(content_lower, ["json", "table", "code", "format"]) or
    String.contains?(content_lower, ["output in", "in format"])
  end
end