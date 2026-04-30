defmodule ElPaso.CLI.Commands.Context do
  @moduledoc """
  Comando para gestionar el contexto de sesiones.
  """

  alias ElPaso.CLI.Output
  alias ElPaso.Context.Storage

  @doc """
  Muestra o exporta el contexto de una sesión.
  """
  def run(opts) do
    session_id = Keyword.get(opts, :session, "default")
    format = Keyword.get(opts, :format, :text)

    session =
      case Storage.get_session(session_id) do
        {:error, _} -> nil
        result -> result
      end

    if session do
      if format == :json do
        render_json(session)
      else
        render_text(session)
      end
    else
      Output.error("Sesión no encontrada: #{session_id}")
    end
  end

  @doc """
  Lista todas las sesiones activas.
  """
  def list_sessions do
    sessions = Storage.list_sessions()

    if sessions == [] do
      Output.info("No hay sesiones activas")
    else
      Output.section("Sesiones activas")

      rows =
        Enum.map(sessions, fn s ->
          [
            s.session_id,
            s.user_id || "—",
            s.status || "—",
            format_datetime(s.inserted_at)
          ]
        end)

      Output.data_table(
        ["ID", "Usuario", "Estado", "Creada"],
        rows
      )
    end
  end

  # Renderizado en texto
  defp render_text(session) when is_map(session) do
    Output.section(session.session_id, subtitle: "Sesión")

    Output.data_table(
      ["Campo", "Valor"],
      [
        ["Usuario", session.user_id || "—"],
        ["Modelo", session.model_id || "—"],
        ["Estado", session.status || "—"],
        ["Modo contexto", session.context_mode || "—"],
        ["Creada", format_datetime(session.inserted_at)],
        ["Última actividad", format_datetime(session.updated_at)]
      ]
    )
  end

  # Renderizado en JSON
  defp render_json(session) when is_map(session) do
    data = %{
      session_id: session.session_id,
      user_id: session.user_id,
      model_id: session.model_id,
      status: session.status,
      context_mode: session.context_mode,
      created_at: format_datetime(session.inserted_at),
      updated_at: format_datetime(session.updated_at)
    }

    Output.json_data(data)
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(dt) do
    case dt do
      %DateTime{} -> DateTime.to_iso8601(dt)
      _ -> to_string(dt)
    end
  end
end
