defmodule ElPaso.Context.SessionSupervisor do
  @moduledoc """
  Supervisor para la gestión de sesiones del sistema.
  """

  use Supervisor

  @impl Supervisor
  def init(_args) do
    children = [
      # Aquí se pueden añadir procesos de gestión de sesiones
    ]

    opts = [strategy: :one_for_one, name: ElPaso.Context.SessionSupervisor]
    Supervisor.init(children, opts)
  end
end
