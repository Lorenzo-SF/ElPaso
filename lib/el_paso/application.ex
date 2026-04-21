defmodule ElPaso.Application do
  alias ModelDownloaderRegistry
  alias ElPaso.Config

  # Helper para obtener el puerto HTTP
  defp http_port do
    Config.http_port() || 8080
  end

  @moduledoc """
  La aplicación principal del proyecto ElPaso.

  Esta aplicación gestiona el arranque de todos los componentes necesarios para 
  el proxy de inferencia multi-modelo.
  """

  use Application

  @impl Application
  def start(_context, _args) do
    # Inicializar Rate Limiter ETS table
    ElPaso.Security.RateLimiter.init()

    # Inicializar ModelDownloader Registry
    ModelDownloaderRegistry.init()

    # Children base
    children = [
      # Supervisor de la gestión de motores de inferencia
      ElPaso.Domain.ModelManager,

      # Supervisor de la gestión de sesiones y conversaciones
      ElPaso.Context.SessionSupervisor,

      # Supervisor para el procesamiento de resúmenes
      ElPaso.Context.SummarizationSupervisor,

      # Servidor de telemetry para métricas
      ElPaso.Telemetry.Store,

      # Servidor HTTP para las APIs REST (usando Plug.Cowboy)
      {Plug.Cowboy, scheme: :http, plug: ElPaso.HTTP.Server, port: http_port()},

      # Supervisor para el manejo de errores y eventos
      ElPaso.Event.Supervisor,

      # AutoTuner para aprendizaje adaptativo
      ElPaso.Domain.AutoTuner
    ]

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
