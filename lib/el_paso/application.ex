defmodule ElPaso.Application do
  alias ModelDownloaderRegistry
  alias ElPaso.Config

  # Helper para obtener el puerto HTTP
  defp http_port do
    Config.http_port() || 8080
  end

  @moduledoc """
  ElPaso Application - OTP supervision tree for the multi-model LLM proxy.

  This application manages the startup of all components required for the multi-model inference proxy.

  ## Supervision Tree

  The main supervision tree includes:

  - **ElPaso.Repo** - Ecto repository for PostgreSQL persistence
  - **ModelManager** - Supervises model lifecycle (start/stop/health)
  - **Telemetry.Store** - Collects metrics and events
  - **HTTP Server** - REST API endpoints (Plug.Cowboy)
  - **AutoTuner** - Adaptive routing optimization
  - **Zaguan.Engine.Supervisor** - Central registry of inference engines (Zaguan)

  ## Cluster Support

  When cluster mode is enabled, additional components are added:

  - **Cluster.Supervisor** - For gossip-based discovery (libcluster)
  - **NodeRegistry** - For static node registration

  ## Configuration

  The application reads configuration from `~/.config/elpaso/elpaso.conf` with fallback to environment variables.
  """

  use Application

  @impl Application
  def start(_context, _args) do
    # Inicializar Rate Limiter ETS table
    ElPaso.Security.RateLimiter.init()

    # Inicializar ModelDownloader Registry
    ModelDownloaderRegistry.init()

    # Inicializar affinity table ETS
    ElPaso.Config.Loader.init_affinity_table()

    # Children base
    base_children = [
      # Ecto Repo supervisor - conexión a PostgreSQL
      {ElPaso.Repo, []},

      # Finch para HTTP client (motor de inferencia)
      {Finch, name: ElPaso.Finch},

      # Task.Supervisor para inferencias asíncronas
      {Task.Supervisor, name: ElPaso.TaskSupervisor},

      # Supervisor de la gestión de motores de inferencia
      ElPaso.Domain.ModelManager,

      # Servidor de telemetry para métricas
      ElPaso.Telemetry.Store,

      # AutoTuner para aprendizaje adaptativo
      ElPaso.Domain.AutoTuner,

      # Motor de inferencia: Registry + Monitor + Leader + Workers (Zaguan)
      Zaguan.Engine.Supervisor
    ]

    # Servidor HTTP solo si no estamos en modo CLI
    http_children =
      if Application.get_env(:elpaso, :cli_mode) do
        []
      else
        [
          {Plug.Cowboy, scheme: :http, plug: ElPaso.HTTP.Server, port: http_port()}
        ]
      end

    children = base_children ++ http_children

    # Añadir cluster support si está habilitado
    final_children =
      cond do
        Config.cluster_enabled?() and Config.cluster_discovery() == "gossip" ->
          # Modo gossip: usar libcluster para descubrimiento automático
          children ++
            [
              {Cluster.Supervisor,
               [
                 gossip: [
                   strategy: Cluster.Strategy.Gossip,
                   config: [
                     port: 45_892,
                     multicast_addr: "230.1.1.251"
                   ]
                 ]
               ]},
              ElPaso.Cluster.NodeRegistry
            ]

        Config.cluster_enabled?() ->
          # Modo static: NodeRegistry suficiente
          children ++ [ElPaso.Cluster.NodeRegistry]

        true ->
          children
      end

    # Arranca la aplicación con los hijos definidos
    opts = [strategy: :one_for_one, name: ElPaso.Supervisor]
    Supervisor.start_link(final_children, opts)
  end
end
