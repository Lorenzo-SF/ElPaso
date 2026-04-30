defmodule ElPaso.Context.SessionSupervisorTest do
  @moduledoc """
  Tests para ElPaso.Context.SessionSupervisor.
  """

  use ExUnit.Case, async: false

  alias ElPaso.Context.SessionSupervisor

  describe "start_link/1" do
    test "inicia el supervisor" do
      assert {:ok, pid} = SessionSupervisor.start_link([])
      assert Process.alive?(pid)
      Supervisor.stop(pid)
    end
  end
end
