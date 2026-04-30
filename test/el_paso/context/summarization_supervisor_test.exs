defmodule ElPaso.Context.SummarizationSupervisorTest do
  @moduledoc """
  Tests para ElPaso.Context.SummarizationSupervisor.
  """

  use ExUnit.Case, async: false

  alias ElPaso.Context.SummarizationSupervisor

  describe "start_link/1" do
    test "inicia el supervisor" do
      assert {:ok, pid} = SummarizationSupervisor.start_link([])
      assert Process.alive?(pid)
      Supervisor.stop(pid)
    end
  end
end
