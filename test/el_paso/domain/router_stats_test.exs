defmodule ElPaso.Domain.RouterStatsTest do
  @moduledoc """
  Tests para ElPaso.Domain.RouterStats.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Domain.RouterStats

  describe "struct" do
    test "tiene valores por defecto" do
      stats = %RouterStats{}
      assert stats.total_decisions == 0
      assert stats.fallback_rate_pct == 0.0
    end
  end

  describe "aggregate/1" do
    test "devuelve struct vacío" do
      assert %RouterStats{} = RouterStats.aggregate(:last_7d)
    end
  end
end
