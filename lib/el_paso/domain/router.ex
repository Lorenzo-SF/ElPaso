defmodule ElPaso.Domain.Router do
  @moduledoc """
  Router de modelos para tomar decisiones sobre qué modelo usar para una solicitud.

  Este módulo implementa la lógica de enrutamiento basada en:
  - Tipo de solicitud
  - Contexto de la conversación
  - Disponibilidad de modelos
  - Costos y rendimiento
  """

  alias ElPaso.Domain.ModelManager
  alias ElPaso.Context.Storage

  @doc """
  Selecciona el modelo adecuado para una solicitud basada en el contexto.

  ## Parámetros

  - `messages` - Lista de mensajes para procesar
  - `options` - Opciones adicionales para la selección

  ## Ejemplo

      iex> Router.select_model(messages, %{})
  """
  @spec select_model(list(), map()) :: {:ok, map()} | {:error, any()}
  def select_model(_messages, _options) do
    # Esta implementación es simplificada - en producción se usaría:
    # - Análisis de contexto del mensaje
    # - Feature vector processing
    # - Model availability checking
    # - Cost/benefit analysis

    # Para este ejemplo, seleccionamos el primer modelo activo
    case ModelManager.list_models() |> Enum.find(& &1.active) do
      nil ->
        {:error, :no_active_model}

      model ->
        {:ok,
         %{
           model_name: model.name,
           engine_id: model.engine_id,
           decision_reason: "Selección por defecto",
           timestamp: DateTime.utc_now()
         }}
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
