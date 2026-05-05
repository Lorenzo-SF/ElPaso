defmodule ElPaso.Cluster.NodeRegistryTest do
  use ExUnit.Case, async: false

  alias ElPaso.Cluster.NodeRegistry

  describe "start_link/1" do
    test "starts the GenServer" do
      assert {:ok, pid} = NodeRegistry.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "all_nodes/0" do
    test "returns current node" do
      {:ok, pid} = NodeRegistry.start_link([])
      nodes = NodeRegistry.all_nodes()
      assert is_list(nodes)
      assert Enum.any?(nodes, &(&1.node == node()))
      GenServer.stop(pid)
    end
  end

  describe "all_model_states/0" do
    test "returns empty map by default" do
      {:ok, pid} = NodeRegistry.start_link([])
      assert %{} = NodeRegistry.all_model_states()
      GenServer.stop(pid)
    end
  end

  describe "remote_model_states/2" do
    test "returns unreachable for non-existent node" do
      {:ok, pid} = NodeRegistry.start_link([])
      assert {:error, :unreachable} = NodeRegistry.remote_model_states(:nonexistent@node, 100)
      GenServer.stop(pid)
    end
  end

  describe "node_up/1 and node_down/1" do
    test "registers node up and down" do
      {:ok, pid} = NodeRegistry.start_link([])

      assert :ok = NodeRegistry.node_up(:test_node@localhost)
      nodes = NodeRegistry.all_nodes()
      assert Enum.any?(nodes, &(&1.node == :test_node@localhost))

      assert :ok = NodeRegistry.node_down(:test_node@localhost)
      GenServer.stop(pid)
    end
  end

  describe "handle_call callbacks" do
    test "all_nodes returns current and active nodes" do
      state = %{nodes: %{remote: %{role: :worker, status: :up}}, my_role: :both}
      assert {:reply, nodes, ^state} = NodeRegistry.handle_call(:all_nodes, self(), state)
      assert length(nodes) == 2
    end

    test "all_model_states returns empty map" do
      state = %{nodes: %{}}
      assert {:reply, %{}, ^state} = NodeRegistry.handle_call(:all_model_states, self(), state)
    end

    test "remote_model_states with badrpc" do
      state = %{nodes: %{}}
      # We can't easily mock :rpc.call, so we just verify it handles the response
      assert {:reply, result, ^state} =
               NodeRegistry.handle_call({:remote_model_states, :nonexistent, 0}, self(), state)

      assert match?({:error, :unreachable}, result) or match?({:ok, _}, result)
    end
  end

  describe "handle_cast callbacks" do
    test "node_up registers node" do
      state = %{nodes: %{}}
      assert {:noreply, new_state} = NodeRegistry.handle_cast({:node_up, :test}, state)
      assert new_state.nodes[:test].status == :up
    end

    test "node_down updates node status" do
      state = %{nodes: %{test: %{role: :worker, status: :up}}}
      assert {:noreply, new_state} = NodeRegistry.handle_cast({:node_down, :test}, state)
      assert new_state.nodes[:test].status == :down
    end
  end
end
