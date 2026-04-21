defmodule ElPaso.Context.SessionSupervisor do
  @moduledoc """
  Supervisor para la gestión de sesiones y conversaciones.
  """

  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  def init(_args) do
    children = [
      ElPaso.Context.SessionWorker,
      ElPaso.Context.MessageWorker,
      ElPaso.Context.ConversationSummaryWorker
    ]

    opts = [strategy: :one_for_one, name: ElPaso.Context.SessionSupervisor]
    Supervisor.init(children, opts)
  end
end
