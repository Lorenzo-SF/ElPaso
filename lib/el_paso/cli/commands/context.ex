defmodule ElPaso.CLI.Commands.Context do
  @moduledoc """
  Comando para exportar el contexto de una sesión.
  """

  alias Zaguan.Drawer.Components.{Header, Message}
  alias ElPaso.Context.Storage

  @doc """
  Exporta una sesión en formato especificado.
  """
  def run(_opts) do
    session_id = "default"
    format = :markdown
    _include_metadata = false

    with {:ok, session} <- Storage.get_session(session_id),
         {:ok, messages} <- Storage.get_all_messages(session_id),
         {:ok, summary} <- Storage.get_latest_summary(session_id) do
      case format do
        :markdown -> render_markdown(session, messages, summary, _include_metadata)
        :json -> render_json(session, messages, summary, _include_metadata)
      end
    else
      error ->
        Message.print(:error, "Error al exportar sesión: #{inspect(error)}")
        {:error, error}
    end
  end

  defp render_markdown(session, messages, summary, _include_metadata) do
    header =
      if _include_metadata do
        """
        # Sesión #{session.id}
        Creada: #{session.created_at} | Última actividad: #{session.last_active_at}

        """
      else
        "# Conversación exportada\n\n"
      end

    summary_block =
      if summary do
        "## Resumen del historial\n#{summary.content}\n\n---\n\n"
      else
        ""
      end

    messages_text =
      messages
      |> Enum.map(fn msg ->
        role = String.capitalize(msg.role)
        "**#{role}**: #{msg.content}\n"
      end)
      |> Enum.join("\n")

    header <> summary_block <> messages_text
  end

  defp render_json(session, messages, summary, _include_metadata) do
    _json_data = %{
      session_id: session.id,
      created_at: session.created_at,
      last_active_at: session.last_active_at
    }

    if summary do
      _json_data = Map.put(_json_data, :summary, summary.content)
    end

    _json_data =
      Map.put(
        _json_data,
        :messages,
        Enum.map(messages, fn msg ->
          %{role: msg.role, content: msg.content, created_at: msg.created_at}
        end)
      )

    _json_data
  end
end
