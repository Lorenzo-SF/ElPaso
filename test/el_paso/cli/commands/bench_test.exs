defmodule ElPaso.CLI.Commands.BenchTest do
  @moduledoc """
  Tests para ElPaso.CLI.Commands.Bench.
  """

  use ExUnit.Case, async: true

  alias ElPaso.CLI.Commands.Bench

  test "run ejecuta benchmark y muestra resumen" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        Bench.run(model: "test-model", requests: 3)
      end)

    assert output =~ "Benchmark ElPaso"
    assert output =~ "Resumen"
    assert output =~ "Latencia media"
  end
end
