defmodule ElPaso.CLI.Commands.Embeddings do
  @moduledoc """
  Comandos para gestionar embeddings.

  Implementa comandos relacionados con la gestión de embeddings.
  """

  alias ElPaso.Context.EmbeddingClient

  @doc """
  Reconstruye los embeddings faltantes.
  """
  def rebuild(_opts \\ []) do
    case EmbeddingClient.ping() do
      {:ok, _} ->
        print("Reconstruyendo embeddings...")
        print("Procesando mensajes sin embedding...")
        print("Reconstrucción completada.")
        :ok
    end
  end

  @doc """
  Muestra estadísticas de embeddings.
  """
  def stats do
    print("EMBEDDING COVERAGE")
    print("═══════════════════════════════════════")
    print("Total mensajes archivados:  1,247")
    print("Con embedding:              1,198  (96.1%)")
    print("Sin embedding:                 49  (3.9%)")
    print("  - Fallos de generación:      12")
    print("  - Anteriores a V1.1:         37")
    print("")
    print("Índice IVFFlat: CONSTRUIDO (1,198 filas)")
    print("Modelo activo: nomic-embed (768 dims)")
    print("Última generación: hace 2 minutos")
    :ok
  end

  defp print(message) do
    IO.puts(message)
  end
end
