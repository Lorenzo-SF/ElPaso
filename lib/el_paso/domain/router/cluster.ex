defmodule ElPaso.Domain.Router.Cluster do
  @moduledoc """
  Versión distribuida del router que agrega estados de todos los nodos del cluster.

  Utiliza RPC con timeout de 500ms para no bloquear el routing cuando
  un nodo no responde. Los nodos que fallan son excluidos del routing.
  """

  require Logger

  alias ElPaso.Cluster.NodeRegistry
  alias ElPaso.Domain.ModelManager

  @doc """
  Devuelve todos los ModelStates de todos los nodos (local + remotos).

  Los estados remotos tienen timeout de 500ms para no bloquear el routing.
  Los nodos que no responden son excluidos.
  """
  @spec all_model_states_global() :: [ModelManager.all_states_result()]
  def all_model_states_global do
    # Estados locales
    local = ModelManager.all_states()

    local_with_node =
      Enum.map(local, fn state ->
        Map.put(state, :node, node())
      end)

    # Si el cluster no está habilitado, solo devolver locales
    if Enum.empty?(NodeRegistry.all_nodes()) do
      local_with_node
    end

    # Obtener estados de nodos remotos
    remote =
      NodeRegistry.all_nodes()
      |> Enum.filter(fn node_info ->
        node_info.role in [:worker, :both] and node_info.node != node()
      end)
      |> Task.async_stream(
        fn node_info ->
          case NodeRegistry.remote_model_states(node_info.node, 500) do
            {:ok, states} ->
              Enum.map(states, fn state ->
                Map.put(state, :node, node_info.node)
              end)

            {:error, _reason} ->
              Logger.warning("Node #{node_info.node} unreachable, excluding from routing")
              []
          end
        end, timeout: 600, on_timeout: :kill_task)
      |> Enum.flat_map(fn
        {:ok, states} -> states
        {:exit, _} -> []
      end)

    local_with_node ++ remote
  end

  @doc """
  Reenvía un request a un nodo remoto vía RPC.
  """
  @spec forward_to_remote_node(atom(), String.t(), String.t(), map()) ::
          {:ok, term()} | {:error, term()}
  def forward_to_remote_node(node, model_id, prompt, params) do
    case :rpc.call(node, ElPaso.Engine.Dispatcher, :infer, [model_id, prompt, params], 60_000) do
      {:badrpc, reason} ->
        Logger.error("RPC to #{node} failed: #{inspect(reason)}")
        {:error, :rpc_failure}

      result ->
        result
    end
  end
end
