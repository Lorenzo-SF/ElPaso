defmodule ElPaso.Context.SummarizationSupervisor do
  @moduledoc """
  Supervisor para la gestión del procesamiento de resúmenes.
  """

  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  def init(_args) do
    children = [
      ElPaso.Context.SummarizationWorker
    ]

    opts = [strategy: :one_for_one, name: ElPaso.Context.SummarizationSupervisor]
    Supervisor.init(children, opts)
  end
end
