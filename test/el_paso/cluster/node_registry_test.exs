defmodule ElPaso.Cluster.NodeRegistryTest do
  @moduledoc """
  Tests para ElPaso.Cluster.NodeRegistry.
  """

  use ExUnit.Case, async: false

  alias ElPaso.Cluster.NodeRegistry

  setup do
    # Prevent net_kernel from starting by disabling cluster
    System.put_env("ELPASO_CLUSTER_ENABLED", "false")
    start_supervised!({NodeRegistry, []})
    :ok
  end

  test "all_nodes incluye nodo actual" do
    nodes = NodeRegistry.all_nodes()
    assert length(nodes) >= 1
    assert Enum.any?(nodes, fn n -> n.node == node() end)
  end

  test "all_model_states devuelve mapa vacío" do
    assert NodeRegistry.all_model_states() == %{}
  end

  test "node_up y node_down registran estado" do
    :ok = NodeRegistry.node_up(:worker1@localhost)
    nodes = NodeRegistry.all_nodes()
    assert Enum.any?(nodes, fn n -> n.node == :worker1@localhost and n.status == :up end)

    :ok = NodeRegistry.node_down(:worker1@localhost)
    nodes = NodeRegistry.all_nodes()
    refute Enum.any?(nodes, fn n -> n.node == :worker1@localhost end)
  end

  test "remote_model_states devuelve error para nodo inexistente" do
    assert NodeRegistry.remote_model_states(:nonexistent, 100) == {:error, :unreachable}
  end
end
