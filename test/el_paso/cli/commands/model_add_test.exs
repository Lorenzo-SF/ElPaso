defmodule ElPaso.CLI.Commands.ModelAddTest do
  @moduledoc """
  Tests para ElPaso.CLI.Commands.ModelAdd.
  """

  use ExUnit.Case, async: true

  alias ElPaso.CLI.Commands.ModelAdd

  test "run muestra uso" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        ModelAdd.run([])
      end)

    assert output =~ "Usage"
  end

  test "run --help muestra ayuda" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        ModelAdd.run(["--help"])
      end)

    assert output =~ "elpaso model add"
  end
end
