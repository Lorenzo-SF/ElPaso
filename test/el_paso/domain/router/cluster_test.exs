defmodule ElPaso.Domain.Router.ClusterTest do
  @moduledoc """
  Tests para ElPaso.Domain.Router.Cluster.
  """

  use ExUnit.Case, async: false

  alias ElPaso.Domain.Router.Cluster

  setup do
    start_supervised!({ElPaso.Cluster.NodeRegistry, []})
    start_supervised!({ElPaso.Domain.ModelManager, []})
    :ok
  end

  describe "all_model_states_global/0" do
    test "devuelve estados locales" do
      states = Cluster.all_model_states_global()
      assert is_list(states)
    end
  end

  describe "forward_to_remote_node/4" do
    test "devuelve error para nodo inalcanzable" do
      assert {:error, :rpc_failure} = Cluster.forward_to_remote_node(:nonexistent, "m1", "p", %{})
    end
  end
end
