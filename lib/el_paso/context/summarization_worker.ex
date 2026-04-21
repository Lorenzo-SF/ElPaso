defmodule ElPaso.Context.SummarizationWorker do
  @moduledoc """
  Worker asíncrono para generar resúmenes de conversaciones.
  """

  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
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

    # En producción: guardar en base de datos
    IO.puts("Resumen generado para sesión #{session_id}: #{summary}")

    {:noreply, state}
  end

  defp generate_summary(_session_id) do
    # Implementación real del resumen
    "Resumen generado"
  end
end
