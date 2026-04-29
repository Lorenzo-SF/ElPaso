defmodule ElPaso.CLITest do
  @moduledoc """
  Tests para ElPaso.CLI.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  alias ElPaso.CLI

  describe "main/1" do
    test "muestra ayuda general" do
      assert capture_io(fn -> CLI.main([]) end) =~ "ElPaso"
    end

    test "muestra ayuda detallada" do
      assert capture_io(fn -> CLI.main(["--help"]) end) =~ "ElPaso"
    end

    test "muestra ayuda de model" do
      assert capture_io(fn -> CLI.main(["model", "--help"]) end) =~ "MODEL"
    end

    test "muestra ayuda de engine" do
      assert capture_io(fn -> CLI.main(["engine", "--help"]) end) =~ "ENGINE"
    end

    test "muestra ayuda de config" do
      assert capture_io(fn -> CLI.main(["config", "--help"]) end) =~ "CONFIG"
    end

    test "muestra ayuda de router" do
      assert capture_io(fn -> CLI.main(["router", "--help"]) end) =~ "ROUTER"
    end

    test "muestra ayuda de bench" do
      assert capture_io(fn -> CLI.main(["bench", "--help"]) end) =~ "BENCH"
    end

    test "muestra ayuda de context" do
      assert capture_io(fn -> CLI.main(["context", "--help"]) end) =~ "CONTEXT"
    end

    test "muestra ayuda de cluster" do
      assert capture_io(fn -> CLI.main(["cluster", "--help"]) end) =~ "CLUSTER"
    end

    test "comando desconocido muestra error" do
      assert capture_io(fn -> CLI.main(["unknown"]) end) =~ "desconocido"
    end
  end
end
