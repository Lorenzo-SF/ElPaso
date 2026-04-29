defmodule ElPaso.Pipeline do
  @moduledoc """
  Pipeline de inferencia para procesar requests a través de modelos y engines.

  Este módulo implementa el flujo completo de procesamiento:
  RequestParser → Router → Engine Dispatcher → Response Handler
  """

  alias ElPaso.Domain.ModelManager
  alias ElPaso.Context.Storage
  alias ElPaso.Engine.Adapter
  alias ElPaso.Domain.Router
  alias ElPaso.Repo
  alias ElPaso.Models.Engine

  @doc """
  Procesa un request de inferencia completo a través del pipeline.

  ## Parámetros

  - `request_id` - ID único del request
  - `session_id` - ID de la sesión actual
  - `messages` - Lista de mensajes para procesar
  - `options` - Opciones adicionales para el procesamiento

  ## Ejemplo

      iex> Pipeline.process_request("req123", "sess456", [%{role: "user", content: "Hola"}], %{})
  """
  @spec process_request(String.t(), String.t(), list(), map()) :: {:ok, any()} | {:error, any()}
  def process_request(request_id, session_id, messages, options) do
    with {:ok, routing_decision} <- Router.select_model(messages, options),
         %{} = model <- ModelManager.get_model(routing_decision.model_name),
         %{} = engine <- Repo.get(Engine, model.engine_id),
         {:ok, response} <-
           execute_inference(request_id, session_id, messages, model, engine, routing_decision),
         {:ok, _} <-
           Storage.save_routing_decision(%{
             request_id: request_id,
             selected_model: routing_decision.model_name,
             outcome: "pending"
           }) do
      {:ok, response}
    else
      nil -> {:error, :model_not_found}
      error -> {:error, error}
    end
  end

  @doc """
  Ejecuta inferencia en un modelo específico usando el engine correspondiente.

  ## Parámetros

  - `request_id` - ID único del request
  - `session_id` - ID de la sesión actual
  - `messages` - Lista de mensajes para procesar
  - `model` - Modelo a usar
  - `engine` - Engine de inferencia
  - `routing_decision` - Decisión de enrutamiento

  ## Ejemplo

      iex> Pipeline.execute_inference("req123", "sess456", [%{role: "user", content: "Hola"}], model, engine, routing_decision)
  """
  @spec execute_inference(String.t(), String.t(), list(), map(), map(), map()) ::
          {:ok, any()} | {:error, any()}
  def execute_inference(_request_id, _session_id, messages, model, engine, _routing_decision) do
    # Usar el adapter apropiado según el tipo de engine
    case engine.adapter do
      "openai" ->
        Adapter.openai(messages, model, engine, %{})

      "anthropic" ->
        Adapter.anthropic(messages, model, engine, %{})

      "ollama" ->
        Adapter.ollama(messages, model, engine, %{})

      "llama_cpp" ->
        Adapter.llama_cpp(messages, model, engine, %{})

      _ ->
        {:error, "Motor de inferencia no soportado: #{engine.adapter}"}
    end
  end

  @doc """
  Procesa un request de streaming.

  ## Parámetros

  - `request_id` - ID único del request
  - `session_id` - ID de la sesión actual
  - `messages` - Lista de mensajes para procesar
  - `options` - Opciones adicionales para el procesamiento

  ## Ejemplo

      iex> Pipeline.stream_request("req123", "sess456", [%{role: "user", content: "Hola"}], %{})
  """
  @spec stream_request(String.t(), String.t(), list(), map()) :: {:ok, any()} | {:error, any()}
  def stream_request(request_id, session_id, messages, options) do
    with {:ok, routing_decision} <- Router.select_model(messages, options),
         %{} = model <- ModelManager.get_model(routing_decision.model_name),
         %{} = engine <- Repo.get(Engine, model.engine_id),
         {:ok, response} <-
           stream_inference(request_id, session_id, messages, model, engine, routing_decision) do
      {:ok, response}
    else
      nil -> {:error, :model_not_found}
      error -> {:error, error}
    end
  end

  @doc """
  Ejecuta inferencia en streaming.

  ## Parámetros

  - `request_id` - ID único del request
  - `session_id` - ID de la sesión actual
  - `messages` - Lista de mensajes para procesar
  - `model` - Modelo a usar
  - `engine` - Engine de inferencia
  - `routing_decision` - Decisión de enrutamiento

  ## Ejemplo

      iex> Pipeline.stream_inference("req123", "sess456", [%{role: "user", content: "Hola"}], model, engine, routing_decision)
  """
  @spec stream_inference(String.t(), String.t(), list(), map(), map(), map()) ::
          {:ok, any()} | {:error, any()}
  def stream_inference(_request_id, _session_id, messages, model, engine, _routing_decision) do
    # Usar el adapter apropiado según el tipo de engine
    case engine.adapter do
      "openai" ->
        Adapter.stream_openai(messages, model, engine, %{})

      "anthropic" ->
        Adapter.stream_anthropic(messages, model, engine, %{})

      "ollama" ->
        Adapter.stream_ollama(messages, model, engine, %{})

      "llama_cpp" ->
        Adapter.stream_llama_cpp(messages, model, engine, %{})

      _ ->
        {:error, "Motor de inferencia no soportado: #{engine.adapter}"}
    end
  end
end
