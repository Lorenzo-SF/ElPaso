defmodule ElPaso.CLI.Commands.ConfigReloadTest do
  @moduledoc """
  Tests para ElPaso.CLI.Commands.ConfigReload.
  """

  use ExUnit.Case, async: true

  alias ElPaso.CLI.Commands.ConfigReload

  test "run muestra configuración" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        ConfigReload.run([])
      end)

    assert output =~ "Configuración Actual"
  end
end
