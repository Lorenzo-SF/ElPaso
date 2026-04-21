defmodule ElPaso.Application do
  @moduledoc """
  La aplicación principal del proyecto ElPaso.
  
  Esta aplicación gestiona el arranque de todos los componentes necesarios para 
  el proxy de inferencia multi-modelo.
  """

  use Application

  @impl Application
  def start(_context, _args) do
    # Configuración de la aplicación
    children = [
      # Supervisor de la gestión de motores de inferencia
      ElPaso.Domain.ModelManager,
      
      # Supervisor de la gestión de sesiones y conversaciones
      ElPaso.Context.SessionSupervisor,
      
      # Supervisor para el procesamiento de resúmenes
      ElPaso.Context.SummarizationSupervisor,
      
      # Servidor HTTP para las APIs REST
      ElPaso.HTTP,
      
      # Supervisor para el manejo de errores y eventos
      ElPaso.Event.Supervisor
    ]

    # Arranca la aplicación con los hijos definidos
    opts = [strategy: :one_for_one, name: ElPaso.Supervisor]
    Supervisor.start_link(children, opts)
  end
end