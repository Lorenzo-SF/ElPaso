defmodule ElPaso.Cluster.NodeRegistry do
  @moduledoc """
  Gestiona el registro de nodos en el cluster.

  Al arrancar, registra el nodo actual y conecta a los nodos configurados.
  Proporciona funciones para obtener el estado de todos los nodos y hacer RPC a nodos remotos.
  """

  use GenServer
  require Logger

  alias ElPaso.Config

  @type node_info :: %{
          node: atom(),
          role: atom(),
          status: :up | :down
        }

  # client API

  @doc """
  Inicia el GenServer.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Devuelve todos los nodos activos con sus roles.
  """
  @spec all_nodes() :: [node_info()]
  def all_nodes do
    GenServer.call(__MODULE__, :all_nodes)
  end

  @doc """
  Devuelve todos los modelos disponibles en todos los nodos.
  """
  @spec all_model_states() :: %{atom() => [map()]}
  def all_model_states do
    GenServer.call(__MODULE__, :all_model_states)
  end

  @doc """
  Obtiene ModelStates de un nodo remoto con timeout.
  """
  @spec remote_model_states(atom(), non_neg_integer()) :: {:ok, [map()]} | {:error, :unreachable}
  def remote_model_states(node, timeout \\ 500) do
    GenServer.call(__MODULE__, {:remote_model_states, node, timeout})
  end

  @doc """
  Registra el estado de un nodo como :up.
  """
  @spec node_up(atom()) :: :ok
  def node_up(node) do
    GenServer.cast(__MODULE__, {:node_up, node})
  end

  @doc """
  Registra el estado de un nodo como :down.
  """
  @spec node_down(atom()) :: :ok
  def node_down(node) do
    GenServer.cast(__MODULE__, {:node_down, node})
  end

  # server callbacks

  @impl true
  def init(_opts) do
    if Config.cluster_enabled?() do
      case Config.node_name() do
        nil ->
          Logger.warning("Cluster enabled but node_name not configured")
          {:ok, %{nodes: %{}, my_role: :both}}

        node_name ->
          # Iniciar net_kernel con shortnames
          case :net_kernel.start([node_name, :shortnames]) do
            {:ok, _pid} ->
              Logger.info("Started net_kernel as #{node_name}")

            {:error, {:already_started, _pid}} ->
              Logger.info("net_kernel already started")

            {:error, reason} ->
              Logger.error("Failed to start net_kernel: #{inspect(reason)}")
          end

          # Conectar a nodos configurados
          connect_to_configured_nodes()

          {:ok, %{nodes: %{}, my_role: Config.node_role()}}
      end
    else
      {:ok, %{nodes: %{}, my_role: :both}}
    end
  end

  @impl true
  def handle_call(:all_nodes, _from, %{nodes: nodes, my_role: my_role} = state) do
    # Filtrar nodos que están :up
    active_nodes =
      nodes
      |> Enum.filter(fn {_node, info} -> info.status == :up end)
      |> Enum.map(fn {node, info} -> %{node: node, role: info.role, status: info.status} end)

    # Añadir el nodo actual
    current_node = [%{node: node(), role: my_role, status: :up}]

    {:reply, current_node ++ active_nodes, state}
  end

  @impl true
  def handle_call(:all_model_states, _from, state) do
    # En una implementación completa, esto Gather ModelStates de todos los nodos
    # Por ahora devolvemos mapa vacío
    {:reply, %{}, state}
  end

  @impl true
  def handle_call({:remote_model_states, node, timeout}, _from, state) do
    result =
      case :rpc.call(node, ElPaso.Domain.ModelManager, :all_states, [], timeout) do
        {:badrpc, _reason} ->
          Logger.warning("RPC failed to #{node}: node unreachable")
          {:error, :unreachable}

        states ->
          {:ok, states}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:node_up, node}, %{nodes: nodes} = state) do
    new_nodes = Map.put(nodes, node, %{role: :worker, status: :up})
    {:noreply, %{state | nodes: new_nodes}}
  end

  @impl true
  def handle_cast({:node_down, node}, %{nodes: nodes} = state) do
    new_nodes = Map.put(nodes, node, %{role: :worker, status: :down})
    {:noreply, %{state | nodes: new_nodes}}
  end

  # private functions

  defp connect_to_configured_nodes do
    config_nodes = Config.cluster_nodes()

    Enum.each(config_nodes, fn node ->
      if node != Node.self() do
        case Node.connect(node) do
          true ->
            Logger.info("Connected to node: #{node}")

          false ->
            Logger.warning("Could not connect to node: #{node}")
        end
      end
    end)
  end
end
