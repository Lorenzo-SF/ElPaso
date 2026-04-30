defmodule ElPaso.Telemetry.StoreTest do
  @moduledoc """
  Tests para ElPaso.Telemetry.Store.
  """

  use ExUnit.Case, async: false

  alias ElPaso.Telemetry.Store

  setup do
    start_supervised!({Store, []})
    :ok
  end

  describe "prefix_cache_hit_ratio/0" do
    test "devuelve 1.0 sin eventos" do
      assert Store.prefix_cache_hit_ratio() == 1.0
    end
  end

  describe "recent_events/1" do
    test "devuelve lista vacía inicialmente" do
      assert Store.recent_events(10) == []
    end

    test "registra eventos de telemetry" do
      :telemetry.execute([:elpaso, :prefix, :hit], %{}, %{})
      :telemetry.execute([:elpaso, :prefix, :miss], %{}, %{})
      # Dar tiempo al cast
      Process.sleep(50)
      events = Store.recent_events(10)
      assert length(events) == 2
    end
  end
end
