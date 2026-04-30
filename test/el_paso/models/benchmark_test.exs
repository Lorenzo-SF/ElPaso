defmodule ElPaso.Models.BenchmarkTest do
  @moduledoc """
  Tests para ElPaso.Models.Benchmark.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Models.Benchmark

  test "struct y changeset" do
    b = %Benchmark{name: "b1", tokens_per_sec: 10.0}
    assert b.name == "b1"
    changeset = Benchmark.changeset(b, %{latency_ms: 100})
    assert changeset.valid?
  end
end
