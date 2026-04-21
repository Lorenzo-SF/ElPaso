defmodule ElPaso.CLI.Commands.Context do
  @moduledoc """
  Comando para mostrar el contexto de una sesión.
  
  Implementado usando Zaguan para la salida.
  """

  alias Zaguan.Drawer.Components.{Header, Table, Message}
  alias ElPaso.Context.Storage
  alias ElPaso.Context.PrefixManager

  @doc """
  Muestra la información del contexto de una sesión.
  """
  def show(session_id, opts \\ []) do
    format = Keyword.get(opts, :format, :text)

    case load_session_context(session_id) do
      {:ok, state, summary, window} ->
        if format == :json do
          # Mostrar en formato JSON
          Zaguan.Drawer.Components.Json.print(build_json_data(state, summary, window, session_id))
        else
          # Mostrar en formato texto
          render_text(state, summary, window, session_id)
        end
      {:error, reason} ->
        Message.print(:error, "Sesión no encontrada: #{reason}")
    end
  end

  # Funciones auxiliares para mostrar contexto
  defp load_session_context(session_id) do
    # Cargar el estado de la sesión
    
    case Storage.get(Session, session_id) do
      nil -> {:error, :not_found}
      session ->
        # Obtener el resumen y ventana
        {:ok, session, nil, []}  # Simplificación para prototipo
    end
  end

  defp render_text(state, summary, window, session_id) do
    Header.print("Sesión #{session_id}",
      subtitle: "Modo: #{state.context_mode} | Último modelo: #{state.last_model_id || "—"}")

    Table.print(
      headers: ["Capa", "Tokens", "Detalle"],
      rows: [
        ["Bloque canónico", "100", "estable"],
        ["Resumen", "50", "hasta msg ##{summary?.covers_until_message_id || "—"}, por #{summary?.generated_by_model || "—"}"],
        ["Semántica", "—", "desactivada"],
        ["Ventana", "#{length(window)}", "#{length(window)} mensajes"],
        ["TOTAL", "150", ""]
      ],
      headers_color: :cyan,
      table_border: :rounded
    )

    # Mostrar presupuesto por modelo
    Table.print(
      headers: ["Modelo", "Tokens libres"],
      rows: [
        ["fast", "3840"],
        ["heavy", "7680"]
      ],
      headers_color: :green,
      table_border: :rounded
    )
  end

  defp build_json_data(state, summary, window, session_id) do
    %{
      session_id: session_id,
      context_mode: state.context_mode,
      layers: %{
        prefix: %{tokens: 100},
        summary: %{tokens: 50, content: summary?.content || ""},
        window: %{count: length(window)},
        semantic: %{status: "disabled"}
      },
      budget: %{
        fast: 3840,
        heavy: 7680
      }
    }
  end
end