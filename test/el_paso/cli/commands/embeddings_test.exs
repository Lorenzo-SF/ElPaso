defmodule ElPaso.CLI.Commands.EmbeddingsTest do
  @moduledoc """
  Tests para ElPaso.CLI.Commands.Embeddings.
  """

  use ExUnit.Case, async: true

  alias ElPaso.CLI.Commands.Embeddings

  describe "rebuild/1" do
    test "reconstruye embeddings exitosamente" do
      assert :ok = Embeddings.rebuild()
    end
  end

  describe "stats/0" do
    test "muestra estadísticas" do
      assert :ok = Embeddings.stats()
    end
  end
end
