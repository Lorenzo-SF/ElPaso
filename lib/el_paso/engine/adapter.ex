defmodule ElPaso.Engine.Adapter do
  @moduledoc """
  Adaptadores para diferentes motores de inferencia.

  Este módulo proporciona la interfaz para conectar con distintos proveedores
  de modelos de lenguaje como OpenAI, Anthropic, Ollama y llama.cpp.

  Cada función recibe:
  - `messages`: lista de mensajes [{role, content}]
  - `model`: schema del modelo (Engine.t)
  - `engine`: schema del engine (Engine.t)
  - `_routing_decision`: información de routing (para métricas/futuro)
  """
  alias ElPaso.Engine.HTTPClient

  # ---------------------------------------------------------------------------
  # OpenAI / OpenAI-compatible API
  # ---------------------------------------------------------------------------

  @doc """
  Ejecuta una llamada a OpenAI API o compatible (groq, together, etc.).
  """
  @spec openai([map()], ElPaso.Models.Model.t(), ElPaso.Models.Engine.t(), map()) ::
          {:ok, map()} | {:error, map()}
  def openai(messages, model, engine, _routing_decision) do
    opts = build_opts(model, engine)

    HTTPClient.openai_compatible(
      model.url || engine.base_url,
      model.name,
      messages,
      opts
    )
  end

  @doc """
  Ejecuta una llamada streaming a OpenAI API o compatible.
  """
  @spec stream_openai([map()], ElPaso.Models.Model.t(), ElPaso.Models.Engine.t(), map(), (map() ->
                                                                                            :ok)) ::
          :ok | {:error, map()}
  def stream_openai(messages, model, engine, _routing_decision, callback) do
    opts = build_opts(model, engine)

    HTTPClient.stream_openai(
      model.url || engine.base_url,
      model.name,
      messages,
      opts,
      callback
    )
  end

  # ---------------------------------------------------------------------------
  # Anthropic
  # ---------------------------------------------------------------------------

  @doc """
  Ejecuta una llamada a Anthropic API.
  """
  @spec anthropic([map()], ElPaso.Models.Model.t(), ElPaso.Models.Engine.t(), map()) ::
          {:ok, map()} | {:error, map()}
  def anthropic(messages, model, engine, _routing_decision) do
    opts = build_opts(model, engine)

    HTTPClient.anthropic(
      model.url || engine.base_url,
      model.name,
      messages,
      opts
    )
  end

  # ---------------------------------------------------------------------------
  # Ollama
  # ---------------------------------------------------------------------------

  @doc """
  Ejecuta una llamada a Ollama (local o remoto).
  """
  @spec ollama([map()], ElPaso.Models.Model.t(), ElPaso.Models.Engine.t(), map()) ::
          {:ok, map()} | {:error, map()}
  def ollama(messages, model, engine, _routing_decision) do
    opts = build_opts(model, engine)

    HTTPClient.ollama(
      model.url || engine.base_url,
      model.name,
      messages,
      opts
    )
  end

  @doc """
  Ejecuta streaming via Ollama.
  """
  @spec stream_ollama([map()], ElPaso.Models.Model.t(), ElPaso.Models.Engine.t(), map(), (map() ->
                                                                                            :ok)) ::
          :ok | {:error, map()}
  def stream_ollama(messages, model, engine, _routing_decision, callback) do
    opts = build_opts(model, engine)

    HTTPClient.stream_ollama(
      model.url || engine.base_url,
      model.name,
      messages,
      opts,
      callback
    )
  end

  # ---------------------------------------------------------------------------
  # llama.cpp
  # ---------------------------------------------------------------------------

  @doc """
  Ejecuta una llamada a servidor llama.cpp (compatible OpenAI).
  """
  @spec llama_cpp([map()], ElPaso.Models.Model.t(), ElPaso.Models.Engine.t(), map()) ::
          {:ok, map()} | {:error, map()}
  def llama_cpp(messages, model, engine, _routing_decision) do
    opts = build_opts(model, engine)

    HTTPClient.llama_cpp(
      model.url || engine.base_url,
      model.name,
      messages,
      opts
    )
  end

  @doc """
  Ejecuta streaming via llama.cpp (compatible OpenAI).
  """
  @spec stream_llama_cpp(
          [map()],
          ElPaso.Models.Model.t(),
          ElPaso.Models.Engine.t(),
          map(),
          (map() -> :ok)
        ) :: :ok | {:error, map()}
  def stream_llama_cpp(messages, model, engine, _routing_decision, callback) do
    opts = build_opts(model, engine)

    HTTPClient.stream_openai(
      model.url || engine.base_url,
      model.name,
      messages,
      opts,
      callback
    )
  end

  # ---------------------------------------------------------------------------
  # Dispatch principal — selecciona adapter según el tipo del engine
  # ---------------------------------------------------------------------------

  @doc """
  Ejecuta inferencia dispatchando al adapter apropiado según el engine.

  Usado por el pipeline de inferencia.
  """
  @spec infer([map()], ElPaso.Models.Model.t(), ElPaso.Models.Engine.t(), map()) ::
          {:ok, map()} | {:error, map()}
  def infer(messages, model, engine, routing_decision \\ %{}) do
    case engine.adapter do
      adapter when adapter in ["openai", "openai_compatible"] ->
        openai(messages, model, engine, routing_decision)

      "anthropic" ->
        anthropic(messages, model, engine, routing_decision)

      "ollama" ->
        ollama(messages, model, engine, routing_decision)

      adapter when adapter in ["llama", "llama_cpp"] ->
        llama_cpp(messages, model, engine, routing_decision)

      adapter ->
        {:error, %{type: :unknown_adapter, adapter: adapter}}
    end
  end

  @doc """
  Ejecuta inferencia con streaming, dispatchando al adapter apropiado.
  """
  @spec stream_infer([map()], ElPaso.Models.Model.t(), ElPaso.Models.Engine.t(), map(), (map() ->
                                                                                           :ok)) ::
          :ok | {:error, map()}
  def stream_infer(messages, model, engine, routing_decision \\ %{}, callback) do
    case engine.adapter do
      adapter when adapter in ["openai", "openai_compatible"] ->
        stream_openai(messages, model, engine, routing_decision, callback)

      "anthropic" ->
        {:error, %{type: :unsupported, message: "Anthropic streaming not yet implemented"}}

      "ollama" ->
        stream_ollama(messages, model, engine, routing_decision, callback)

      adapter when adapter in ["llama", "llama_cpp"] ->
        stream_llama_cpp(messages, model, engine, routing_decision, callback)

      adapter ->
        {:error, %{type: :unknown_adapter, adapter: adapter}}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp build_opts(model, engine) do
    [
      api_key: model.api_key || engine.api_key || "",
      temperature: model.temperature || 0.7,
      max_tokens: model.max_tokens || 4096,
      top_p: model.top_p || 1.0,
      timeout: get_in(engine.config || %{}, [:timeout]) || 120_000
    ]
  end
end
