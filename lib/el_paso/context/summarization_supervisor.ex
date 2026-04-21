defmodule ElPaso.Context.SummarizationSupervisor do
  @moduledoc """
  Supervisor para la gestión de procesamiento de resúmenes.
  """

  use Supervisor

  @impl Supervisor
  def init(_args) do
    children = [
      # Aquí se pueden añadir procesos de gestión de resúmenes
    ]

    opts = [strategy: :one_for_one, name: ElPaso.Context.SummarizationSupervisor]
    Supervisor.init(children, opts)
  end
end
