defmodule ElPaso.Context.EmbeddingClient do
  @moduledoc """
  Cliente para generar embeddings usando el modelo de embeddings.
  """

  @doc """
  Verifica si el modelo de embeddings está disponible.
  """
  def ping do
    {:error, :not_configured}
  end

  @doc """
  Genera embeddings para un texto.
  """
  def embed(_text) do
    {:error, :not_configured}
  end

  @doc """
  Genera embeddings para múltiples textos en batch.
  """
  def embed_batch(_texts) do
    {:error, :not_configured}
  end
end
