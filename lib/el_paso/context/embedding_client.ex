defmodule ElPaso.Context.EmbeddingClient do
  @moduledoc """
  Cliente para generar embeddings usando modelos de texto.

  Soporta tanto modelos locales como APIs externas.
  """

  defstruct [
    :model_id,
    :engine_type,
    :base_url,
    :api_key,
    :timeout
  ]

  @doc """
  Crea un nuevo cliente de embeddings.
  """
  def new(model_id) do
    # Simulación temporal para evitar errores de compilación
    %ElPaso.Context.EmbeddingClient{
      model_id: model_id,
      engine_type: "ollama",
      base_url: "",
      api_key: "",
      timeout: 30
    }
  end

  @doc """
  Genera embeddings para un conjunto de textos.
  """
  def generate_embeddings(%ElPaso.Context.EmbeddingClient{} = _client, _texts) do
    # Simulación temporal para evitar errores de compilación
    {:ok, []}
  end

  @doc """
  Genera un embedding para un solo texto.
  """
  def generate_embedding(%ElPaso.Context.EmbeddingClient{} = _client, _text) do
    # Simulación temporal para evitar errores de compilación
    {:ok, []}
  end

  @doc """
  Rebuild embeddings para mensajes sin embedding.
  """
  def rebuild_embeddings(_session_id) do
    # Simulación temporal para evitar errores de compilación
    :ok
  end

  @doc """
  Verifica si el cliente está disponible.
  """
  def ping do
    # Simulación temporal para evitar errores de compilación
    {:ok, "Embedding client is available"}
  end
end
