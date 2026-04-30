defmodule ElPaso.Context.SummarizationWorkerTest do
  @moduledoc """
  Tests para ElPaso.Context.SummarizationWorker.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Context.SummarizationWorker

  test "inicia y recibe cast" do
    {:ok, pid} = SummarizationWorker.start_link([])
    assert :ok = SummarizationWorker.summarize_conversation(pid, "sess-1")
  end
end
