defmodule ElPaso.CLI.Commands.ClusterStatusTest do
  @moduledoc """
  Tests para ElPaso.CLI.Commands.ClusterStatus.
  """

  use ExUnit.Case, async: false

  alias ElPaso.CLI.Commands.ClusterStatus
  alias ElPaso.Cluster.NodeRegistry

  test "run con cluster deshabilitado" do
    System.put_env("ELPASO_CLUSTER_ENABLED", "false")

    output =
      ExUnit.CaptureIO.capture_io(fn ->
        ClusterStatus.run([])
      end)

    assert output =~ "DESHABILITADO"
  end

  test "run con cluster habilitado" do
    System.put_env("ELPASO_CLUSTER_ENABLED", "true")
    System.put_env("ELPASO_NODE_NAME", "testnode")
    System.put_env("ELPASO_CLUSTER_DISCOVERY", "static")

    start_supervised!({NodeRegistry, []})

    output =
      ExUnit.CaptureIO.capture_io(fn ->
        ClusterStatus.run([])
      end)

    assert output =~ "HABILITADO"
  end
end
