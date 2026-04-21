defmodule ElPaso.Context.EmbeddingClient do
  @moduledoc """
  Cliente que abstrae la generación de embeddings, independientemente del motor que los produzca.
  
  llama-server expone el endpoint `/v1/embeddings` compatible con OpenAI.
  """

  alias ElPaso.Context.Schemas.Message

  @doc """
  Genera embedding para un texto dado usando el modelo configurado en embeddings.model_id
  """
  def embed(text) do
    # Implementación simplificada - en producción se usaría el cliente HTTP
    
    case get_embedding_model() do
      {:ok, model_id} ->
        # Llamar al motor de embeddings para generar el vector
        # Esta es una implementación simplificada
        {:ok, [0.1, 0.2, 0.3, 0.4]}  # Vector dummy
      {:error, _} ->
        {:error, :model_unavailable}
    end
  end

  @doc """
  Genera embeddings para un lote de textos en una sola llamada
  """
  def embed_batch(texts) do
    # Implementación simplificada - en producción se usaría el cliente HTTP
    
    case get_embedding_model() do
      {:ok, model_id} ->
        # Llamar al motor de embeddings para generar los vectores
        # Esta es una implementación simplificada
        Enum.map(texts, fn _ -> [0.1, 0.2, 0.3, 0.4] end)  # Vectores dummy
      {:error, _} ->
        {:error, :model_unavailable}
    end
  end

  @doc """
  Verifica que el modelo de embeddings está disponible y responde
  """
  def ping() do
    # Implementación simplificada - en producción se usaría la llamada HTTP
    
    case get_embedding_model() do
      {:ok, _} -> :ok
      {:error, _} -> {:error, :model_unavailable}
    end
  end

  @doc """
  Devuelve la dimensión del vector del modelo de embeddings activo
  """
  def dimensions() do
    # Implementación simplificada - en producción se usaría la configuración
    
    case get_embedding_model() do
      {:ok, model_id} ->
        # En producción se obtendría desde la configuración o el modelo
        {:ok, 768}
      {:error, _} ->
        {:error, :not_configured}
    end
  end

  # Funciones auxiliares
  defp get_embedding_model() do
    # Obtener el modelo de embeddings desde la configuración
    
    # Esta implementación es simplificada
    {:ok, "nomic-embed"}
  end
end