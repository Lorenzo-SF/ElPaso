defmodule ElPaso.Telemetry.StoreTest do
  @moduledoc """
  Tests para ElPaso.Telemetry.Store.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Telemetry.Store

  describe "start_link/1" do
    test "inicia el store" do
      assert {:ok, _pid} = Store.start_link([])
    end
  end
end
