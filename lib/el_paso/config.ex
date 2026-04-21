defmodule ElPaso.Config do
  @moduledoc """
  Módulo para gestión de configuración del sistema.
  """

  defmodule Loader do
    @moduledoc """
    Stub para cargar configuración del sistema.
    """

    @default_config %{
      auth: %{
        enabled: false,
        allow_anonymous: true,
        users: []
      },
      integrations: %{
        claude_code: %{
          model_mapping: %{}
        }
      },
      cluster: %{
        enabled: false,
        node_name: nil,
        role: :both,
        coordinator_nodes: [],
        worker_nodes: [],
        discovery: "static"
      }
    }

    @doc """
    Devuelve la configuración actual del sistema.
    """
    def get do
      @default_config
    end
  end

  @doc """
  Devuelve true si el cluster está habilitado.
  """
  def cluster_enabled? do
    config = Loader.get()
    get_in(config, [:cluster, :enabled]) == true
  end

  @doc """
  Devuelve el rol del nodo actual (:coordinator, :worker, :both).
  """
  def node_role do
    config = Loader.get()
    get_in(config, [:cluster, :role]) || :both
  end

  @doc """
  Devuelve el nombre del nodo actual.
  """
  def node_name do
    config = Loader.get()
    get_in(config, [:cluster, :node_name])
  end

  @doc """
  Devuelve la lista de nodos coordinadores configurados.
  """
  def coordinator_nodes do
    config = Loader.get()
    get_in(config, [:cluster, :coordinator_nodes]) || []
  end

  @doc """
  Devuelve la lista de nodos workers configurados.
  """
  def worker_nodes do
    config = Loader.get()
    get_in(config, [:cluster, :worker_nodes]) || []
  end

  @doc """
  Devuelve todos los nodos configurados para conectar.
  """
  def cluster_nodes do
    coordinator_nodes() ++ worker_nodes()
  end

  @doc """
  Devuelve la estrategia de descubrimiento (:static, :gossip).
  """
  def cluster_discovery do
    config = Loader.get()
    get_in(config, [:cluster, :discovery]) || "static"
  end

  @doc """
  Devuelve true si estamos en modo cluster.
  """
  def cluster_mode? do
    cluster_enabled?()
  end

  @doc """
  Carga la configuración del sistema.
  """
  def load_config do
    # Implementación temporal
    %{}
  end

  @doc """
  Guarda la configuración del sistema.
  """
  def save_config(_config) do
    # Implementación temporal
    :ok
  end
end
