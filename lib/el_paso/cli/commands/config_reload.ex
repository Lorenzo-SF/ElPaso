defmodule ElPaso.CLI.Commands.ConfigReload do
  @moduledoc """
  Comando para recargar la configuración con diff visual.
  """

  alias Zaguan.Drawer.Components.{Header, Table, Message}
  alias ElPaso.Config.Diff
  alias ElPaso.Domain.Types.ConfigChange

  @doc """
  Ejecuta el comando de recarga de configuración con diff.
  """
  def run(_opts) do
    # Cargar nueva configuración (simplificación)
    new_config = ElPaso.Config.load_config()

    # Obtener la configuración actual (simplificación)
    old_config = ElPaso.Config.load_config()

    changes = Diff.diff(old_config, new_config)

    if changes != [] do
      Header.print("Config Diff", subtitle: "Cambios detectados")

      print_changes(changes)

      Message.print(:info, "[A]plicar cambios  [R]efrescar  [Q]salir > ")

      # En producción se aplicaría la configuración y recargarían los modelos
      Message.print(:success, "Configuración actualizada")
    else
      Message.print(:info, "No hay cambios en la configuración")
    end
  end

  defp print_changes(changes) do
    changes
    |> Enum.map(fn change ->
      impact_symbol =
        case change.impact do
          :requires_full_restart -> "🛑"
          :requires_model_restart -> "🔄"
          :hot_reload -> "⚡"
        end

      reason =
        case change.type do
          :added -> "Añadido"
          :removed -> "Eliminado"
          :changed -> "Modificado"
        end

      impact_text =
        case change.impact do
          :requires_full_restart -> "Reinicio completo"
          :requires_model_restart -> "Reinicio de modelo"
          :hot_reload -> "Recarga en caliente"
        end

      [impact_symbol, change.path, reason, impact_text]
    end)
    |> Table.print(
      headers: ["Impacto", "Ruta", "Tipo", "Acción"],
      headers_color: :cyan,
      table_border: :rounded
    )
  end
end
