defmodule ElPaso.Event.SupervisorTest do
  @moduledoc """
  Tests para ElPaso.Event.Supervisor.
  """

  use ExUnit.Case, async: false

  test "inicia el supervisor" do
    assert {:ok, pid} = ElPaso.Event.Supervisor.start_link([])
    assert Process.alive?(pid)
    Supervisor.stop(pid)
  end
end
