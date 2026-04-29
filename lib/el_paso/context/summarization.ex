defmodule ElPaso.Context.Summarization do
  @moduledoc """
  Worker para generar resúmenes de conversaciones.

  Este worker se encarga de procesar solicitudes de resumen usando modelos de lenguaje.
  """

  use GenServer

  alias ElPaso.Context.Storage
  alias ElPaso.Pipeline

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(_args) do
    {:ok, %{}}
  end

  @doc """
  Inicia un proceso de resumen para una sesión.
  """
  def summarize_session(session_id) do
    GenServer.cast(__MODULE__, {:summarize_session, session_id})
  end

  @doc """
  Procesa el resumen de una sesión.
  """
  def process_summary(%{session_id: session_id} = _opts) do
    # Obtener mensajes de la sesión
    messages = Storage.get_all_messages(session_id)

    # Crear prompt para resumen
    summary_prompt = build_summary_prompt(messages)

    # Usar el pipeline para generar el resumen
    case Pipeline.process_request(
           "summary_#{session_id}",
           session_id,
           [%{role: "user", content: summary_prompt}],
           %{model: "gpt-4", temperature: 0.3}
         ) do
      {:ok, response} ->
        # Guardar el resumen en la base de datos
        Storage.create_summary(%{
          session_id: session_id,
          content: response.content,
          token_count: response.token_count,
          generated_at: DateTime.utc_now()
        })

        {:ok, response}

      error ->
        error
    end
  end

  def handle_cast({:summarize_session, session_id}, state) do
    # Procesar el resumen en segundo plano
    Task.start(fn ->
      process_summary(%{session_id: session_id})
    end)

    {:noreply, state}
  end

  defp build_summary_prompt(messages) do
    # Construye un prompt para resumir la conversación
    prompt = """
    Resume brevemente la siguiente conversación en español. 
    Incluye los puntos principales y el contexto general:

    #{Enum.map_join(messages, "\n", fn msg -> "#{msg.role}: #{msg.content}" end)}
    """

    prompt
  end
end
