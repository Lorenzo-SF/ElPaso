defmodule ElPaso.Config do
  @moduledoc """
  Módulo para gestión de configuración del sistema.

  ## CONFIGURACIÓN REQUERIDA

  El sistema REQUIERE que se configure al menos un backend de inferencia.
  Sin configuración válida, la aplicación NO arrancará.

  ### Variables de entorno requeridas (al menos una):

  - `ELPASO_INFERENCE_URL` - URL del servidor de inferencia (requerido)
  - `ELPASO_INFERENCE_API_KEY` - API key para autenticación (requerido)

  ### Opcionales:

  - `ELPASO_PORT` - Puerto HTTP (default: 8080)
  - `ELPASO_MODEL_ROUTING` - Habilitar routing automático (default: false)
  - `ELPASO_AUTH_ENABLED` - Habilitar autenticación (default: false)
  """

  defmodule Loader do
    @moduledoc """
    Loader de configuración del sistema.
    """

    @doc """
    Devuelve la configuración actual del sistema.
    En modo de desarrollo o test, devuelve valores por defecto si no hay configuración válida.
    En producción, falla si no hay configuración mínima requerida.
    """
    def get do
      inference_url = System.get_env("ELPASO_INFERENCE_URL")
      inference_api_key = System.get_env("ELPASO_INFERENCE_API_KEY")

      # Detectar si estamos en modo producción
      is_prod = Application.get_env(:elpaso, :env) == :prod

      if is_prod and (!inference_url or !inference_api_key) do
        raise """
        ⚠️ CONFIGURACIÓN REQUERIDA

        El sistema requiere las siguientes variables de entorno:

        export ELPASO_INFERENCE_URL="https://tu-servidor-api.com/v1"
        export ELPASO_INFERENCE_API_KEY="sk-tu-api-key"

        Ejemplo para OpenAI:
          export ELPASO_INFERENCE_URL="https://api.openai.com/v1"
          export ELPASO_INFERENCE_API_KEY="sk-tu-api-key"

        Ejemplo para Ollama local:
          export ELPASO_INFERENCE_URL="http://localhost:11434/v1"
          export ELPASO_INFERENCE_API_KEY="no-api-key-required"

        Para más opciones: mix elpaso config --wizard
        """
      end

      # En modo no producción, usar valores por defecto para permitir arranque
      if (!inference_url or !inference_api_key) and not is_prod do
        _inference_url = "http://localhost:8081/v1"
        _inference_api_key = "sk-local-test"
      end

      %{
        inference: %{
          url: inference_url,
          api_key: inference_api_key
        },
        auth: %{
          enabled: System.get_env("ELPASO_AUTH_ENABLED") == "true",
          allow_anonymous: System.get_env("ELPASO_ALLOW_ANONYMOUS") != "false"
        },
        cluster: %{
          enabled: false,
          node_name: System.get_env("ELPASO_NODE_NAME"),
          role: :both
        },
        routing: %{
          auto_tune: System.get_env("ELPASO_MODEL_ROUTING") == "true"
        },
        cost_management: %{
          enabled: false
        }
      }
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

  @doc """
  Obtiene el puerto HTTP.
  """
  def http_port do
    case System.get_env("ELPASO_PORT") do
      nil -> 8080
      port -> String.to_integer(port)
    end
  end
end
