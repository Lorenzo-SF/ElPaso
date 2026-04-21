defmodule ElPaso.CLI.Commands.Context do
  @moduledoc """
  Comando para exportar el contexto de una sesión.
  """

  @doc """
  Exporta una sesión en formato especificado.
  """
  def run(_opts) do
    session_id = "default"

    # Simulamos datos para demo
    session = %{
      id: session_id,
      created_at: DateTime.utc_now(),
      last_active_at: DateTime.utc_now()
    }

    messages = []
    summary = nil

    render_markdown(session, messages, summary)
  end

  defp render_markdown(_session, messages, summary) do
    header = "# Conversación exportada\n\n"

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
end
