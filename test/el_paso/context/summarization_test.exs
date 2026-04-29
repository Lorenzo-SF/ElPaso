defmodule ElPaso.Context.SummarizationTest do
  @moduledoc """
  Tests para ElPaso.Context.Summarization.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Context.Summarization

  describe "start_link/1" do
    test "inicia el worker" do
      assert {:ok, _pid} = Summarization.start_link([])
    end
  end
end
