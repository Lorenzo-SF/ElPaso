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
  def select_model(messages, options) do
    # Esta implementación es simplificada - en producción se usaría:
    # - Análisis de contexto del mensaje
    # - Feature vector processing
    # - Model availability checking
    # - Cost/benefit analysis
    
    # Para este ejemplo, seleccionamos un modelo por defecto
    case ModelManager.get_model("default") do
      {:ok, model} ->
        {:ok, %{
          model_name: model.name,
          engine_name: model.engine_name,
          decision_reason: "Selección por defecto",
          timestamp: DateTime.utc_now()
        }}
      
      {:error, reason} ->
        {:error, reason}
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
      {:ok, model} ->
        {:ok, %{
          name: model.name,
          status: model.status,
          availability: model.availability,
          performance: model.performance,
          cost_per_token: model.cost_per_token
        }}
      
      {:error, reason} ->
        {:error, reason}
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
      {:ok, model} ->
        {:ok, model.routing_config}
      
      {:error, reason} ->
        {:error, reason}
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
    case Storage.update_routing_outcome(request_id, routing_decision) do
      :ok ->
        :ok
      
      {:error, reason} ->
        {:error, reason}
    end
  end
end