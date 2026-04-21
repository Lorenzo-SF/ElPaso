defmodule ElPaso.Context.SummarizationWorker do
  @moduledoc """
  Worker asíncrono para generar resúmenes de conversaciones.
  """

  use GenServer

  alias ElPaso.Context.Schemas.ConversationSummary

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(state) do
    {:ok, state}
  end

  @doc """
  Genera un resumen de una conversación.
  """
  def summarize_conversation(pid, session_id) do
    GenServer.cast(pid, {:summarize, session_id})
  end

  @impl GenServer
  def handle_cast({:summarize, session_id}, state) do
    # Lógica para generar el resumen
    summary = generate_summary(session_id)

    # Guardar el resumen en la base de datos
    {:ok, _} =
      ElPaso.Context.Repo.insert(%ConversationSummary{
        session_id: session_id,
        content: summary
      })

    {:noreply, state}
  end

  defp generate_summary(_session_id) do
    # Implementación real del resumen
    "Resumen generado"
  end
end
