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

  # Detect task type from message content
  defp detect_task_type(messages) do
    # Simple heuristic based on message content
    content =
      messages
      |> Enum.map(fn
        %{"content" => c} -> c
        %{content: c} -> c
        _ -> ""
      end)
      |> Enum.join(" ")
      |> String.downcase()

    cond do
      String.contains?(content, [
        "write code",
        "function",
        "implement",
        "algorithm",
        "fibonacci",
        "sort"
      ]) ->
        :code

      String.contains?(content, ["translate", "traduce", "translation"]) ->
        :translation

      String.contains?(content, ["summarize", "resumen", "summary"]) ->
        :summarization

      String.contains?(content, ["analyze", "analysis", "compar", "advantage", "vs "]) ->
        :reasoning

      String.contains?(content, ["what is", "explain", "describe", "definition"]) ->
        :question_answer

      true ->
        :unknown
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
