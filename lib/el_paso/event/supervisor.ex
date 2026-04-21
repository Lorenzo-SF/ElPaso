defmodule ElPaso.Event.Supervisor do
  @moduledoc """
  Supervisor para la gestión de eventos y errores del sistema.
  """

  use Supervisor

  @impl Supervisor
  def init(_args) do
    children = [
      # Aquí se pueden añadir supervisores de eventos o procesos de error
    ]

    opts = [strategy: :one_for_one, name: ElPaso.Event.Supervisor]
    Supervisor.init(children, opts)
  end
end
