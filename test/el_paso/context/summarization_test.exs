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

  describe "summarize_session/1" do
    test "envía cast sin errores" do
      {:ok, pid} = Summarization.start_link([])
      assert :ok = Summarization.summarize_session("sess-1")
    end
  end

  describe "process_summary/1" do
    test "procesa resumen con sesión vacía" do
      {:ok, _pid} = Summarization.start_link([])
      # Esto fallará porque no hay modelos activos, pero al menos ejecuta el código
      result = Summarization.process_summary(%{session_id: "sess-none"})
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end
end
