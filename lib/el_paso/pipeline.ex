defmodule ElPaso.Pipeline do
  @moduledoc """
  Pipeline de inferencia para procesar requests a través de modelos y engines.
  
  Este módulo implementa el flujo completo de procesamiento:
  RequestParser → Router → Engine Dispatcher → Response Handler
  """

  alias ElPaso.Domain.ModelManager
  alias ElPaso.Domain.EngineManager
  alias ElPaso.Context.Storage
  alias ElPaso.Engine.Adapter
  alias ElPaso.Domain.Router

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
           {:ok, model} <- ModelManager.get_model(routing_decision.model_name),
           {:ok, engine} <- EngineManager.get_engine(model.engine_name),
           {:ok, response} <- execute_inference(request_id, session_id, messages, model, engine, routing_decision),
           {:ok, _} <- Storage.save_routing_decision(request_id, routing_decision) do
      {:ok, response}
    else
      error ->
        {:error, error}
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
  @spec execute_inference(String.t(), String.t(), list(), map(), map(), map()) :: {:ok, any()} | {:error, any()}
  def execute_inference(request_id, session_id, messages, model, engine, routing_decision) do
    # Usar el adapter apropiado según el tipo de engine
    case engine.type do
      "openai" ->
        Adapter.openai(messages, model, engine, routing_decision)
      
      "anthropic" ->
        Adapter.anthropic(messages, model, engine, routing_decision)
      
      "ollama" ->
        Adapter.ollama(messages, model, engine, routing_decision)
      
      "llama_cpp" ->
        Adapter.llama_cpp(messages, model, engine, routing_decision)
      
      _ ->
        {:error, "Motor de inferencia no soportado: #{engine.type}"}
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
          {:ok, model} <- ModelManager.get_model(routing_decision.model_name),
          {:ok, engine} <- EngineManager.get_engine(model.engine_name),
          {:ok, response} <- stream_inference(request_id, session_id, messages, model, engine, routing_decision) do
      {:ok, response}
    else
      error ->
        {:error, error}
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
  @spec stream_inference(String.t(), String.t(), list(), map(), map(), map()) :: {:ok, any()} | {:error, any()}
  def stream_inference(request_id, session_id, messages, model, engine, routing_decision) do
    # Usar el adapter apropiado según el tipo de engine
    case engine.type do
      "openai" ->
        Adapter.stream_openai(messages, model, engine, routing_decision)
      
      "anthropic" ->
        Adapter.stream_anthropic(messages, model, engine, routing_decision)
      
      "ollama" ->
        Adapter.stream_ollama(messages, model, engine, routing_decision)
      
      "llama_cpp" ->
        Adapter.stream_llama_cpp(messages, model, engine, routing_decision)
      
      _ ->
        {:error, "Motor de inferencia no soportado: #{engine.type}"}
    end
  end
end