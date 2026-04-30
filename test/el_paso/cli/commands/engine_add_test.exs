defmodule ElPaso.CLI.Commands.EngineAddTest do
  @moduledoc """
  Tests para ElPaso.CLI.Commands.EngineAdd.
  """

  use ExUnit.Case, async: true

  alias ElPaso.CLI.Commands.EngineAdd

  test "run muestra uso" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        EngineAdd.run([])
      end)

    assert output =~ "Usage"
  end

  test "run --help muestra ayuda" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        EngineAdd.run(["--help"])
      end)

    assert output =~ "elpaso engine add"
  end
end
