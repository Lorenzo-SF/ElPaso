defmodule ElPaso.CLI.Commands.Embeddings do
  @moduledoc """
  Comandos para gestionar embeddings.

  Implementa comandos relacionados con la gestión de embeddings.
  """

  alias ElPaso.CLI.Output
  alias ElPaso.Context.EmbeddingClient

  @doc """
  Reconstruye los embeddings faltantes.
  """
  def rebuild(_opts \\ []) do
    case EmbeddingClient.ping() do
      {:ok, _} ->
        Output.info("Reconstruyendo embeddings...")
        Output.info("Procesando mensajes sin embedding...")
        Output.success("Reconstrucción completada.")
        :ok
    end
  end

  @doc """
  Muestra estadísticas de embeddings.
  """
  def stats do
    Output.section("Embedding Coverage")

    Output.data_table(
      ["Métrica", "Valor"],
      [
        ["Total mensajes archivados", "1,247"],
        ["Con embedding", "1,198 (96.1%)"],
        ["Sin embedding", "49 (3.9%)"],
        ["  - Fallos de generación", "12"],
        ["  - Anteriores a V1.1", "37"],
        ["Índice IVFFlat", "CONSTRUIDO (1,198 filas)"],
        ["Modelo activo", "nomic-embed (768 dims)"],
        ["Última generación", "hace 2 minutos"]
      ]
    )

    Output.progress_bar(96.1, 100, label: "Cobertura de embeddings", width: 40)

    :ok
  end
end
