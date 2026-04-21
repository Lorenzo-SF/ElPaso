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
      },
      routing: %{
        auto_tune: false,
        auto_tune_min_confidence: 0.85,
        auto_tune_min_decisions: 50,
        auto_tune_check_interval_hours: 24
      },
      cost_management: %{
        enabled: false,
        daily_usd: 100.0,
        alert_at_pct: 80
      }
    }

    @doc """
    Devuelve la configuración actual del sistema.
    """
    def get do
      @default_config
    end

    @doc """
    Obtiene la affinity para una combinación.
    """
    def get_affinity(_model_id, _task_type) do
      0.5
    end

    @doc """
    Actualiza la affinity para una combinación.
    """
    def update_affinity(_model_id, _task_type, _affinity) do
      :ok
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

  # === Auto-tune config ===

  @doc """
  Devuelve true si auto_tune está habilitado.
  """
  def auto_tune_enabled? do
    config = Loader.get()
    get_in(config, [:routing, :auto_tune]) == true
  end

  @doc """
  Devuelve la confianza mínima para auto-aplicar sugerencias.
  """
  def auto_tune_min_confidence do
    config = Loader.get()
    get_in(config, [:routing, :auto_tune_min_confidence]) || 0.85
  end

  @doc """
  Devuelve el número mínimo de decisiones para auto-aplicar.
  """
  def auto_tune_min_decisions do
    config = Loader.get()
    get_in(config, [:routing, :auto_tune_min_decisions]) || 50
  end

  @doc """
  Devuelve el intervalo de verificación en horas.
  """
  def auto_tune_check_interval_hours do
    config = Loader.get()
    get_in(config, [:routing, :auto_tune_check_interval_hours]) || 24
  end

  # === Cost management config ===

  @doc """
  Devuelve true si cost_management está habilitado.
  """
  def cost_management_enabled? do
    config = Loader.get()
    get_in(config, [:cost_management, :enabled]) == true
  end

  @doc """
  Devuelve el budget diario en USD.
  """
  def daily_usd_limit do
    config = Loader.get()
    get_in(config, [:cost_management, :daily_usd]) || 100.0
  end

  @doc """
  Devuelve el porcentaje de alert para el budget.
  """
  def cost_alert_at_pct do
    config = Loader.get()
    get_in(config, [:cost_management, :alert_at_pct]) || 80
  end

  @doc """
  Obtiene la affine para una combinación (model, task_type).
  """
  def get_affinity(model_id, task_type) do
    Loader.get_affinity(model_id, task_type)
  end

  @doc """
  Actualiza la affinity para una combinación.
  """
  def update_affinity(model_id, task_type, affinity) do
    Loader.update_affinity(model_id, task_type, affinity)
  end

  @doc """
  Carga la configuración del sistema.
  """
  def load_config do
    %{}
  end

  @doc """
  Guarda la configuración del sistema.
  """
  def save_config(_config) do
    :ok
  end
end
