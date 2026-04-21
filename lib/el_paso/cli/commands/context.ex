defmodule ElPaso.CLI.Commands.Context do
  @moduledoc """
  Comando para gestionar el contexto de sesiones.
  """

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
      IO.puts("Sesión no encontrada: #{session_id}")
    end
  end

  @doc """
  Lista todas las sesiones activas.
  """
  def list_sessions do
    IO.puts("Lista de sesiones (por implementar)")
  end

  # Renderizado en texto
  defp render_text(session) when is_map(session) do
    IO.puts("\n=== Sesión #{session.id} ===")
    IO.puts("Usuario: #{session.user_id || "—"}")
    IO.puts("Modelo: #{session.model_id || "—"}")
    IO.puts("Estado: #{session.status || "—"}")
    IO.puts("Modo contexto: #{session.context_mode || "—"}")
    IO.puts("Creada: #{format_datetime(session.inserted_at)}")
    IO.puts("Última actividad: #{format_datetime(session.updated_at)}")
    IO.puts("")
  end

  # Renderizado en JSON
  defp render_json(session) when is_map(session) do
    data = %{
      session_id: session.id,
      user_id: session.user_id,
      model_id: session.model_id,
      status: session.status,
      context_mode: session.context_mode,
      created_at: format_datetime(session.inserted_at),
      updated_at: format_datetime(session.updated_at)
    }

    IO.puts(Jason.encode!(data, pretty: true))
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(dt) do
    case dt do
      %DateTime{} -> DateTime.to_iso8601(dt)
      _ -> to_string(dt)
    end
  end
end
