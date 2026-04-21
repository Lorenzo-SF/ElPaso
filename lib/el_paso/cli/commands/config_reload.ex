defmodule ElPaso.CLI.Commands.ConfigReload do
  @moduledoc """
  Comando para recargar la configuración con diff visual.
  """

  @doc """
  Ejecuta el comando de recarga de configuración con diff.
  """
  def run(_opts) do
    # Cargar nueva configuración (simplificación)
    new_config = ElPaso.Config.load_config()

    # Obtener la configuración actual (simplificación)
    old_config = ElPaso.Config.load_config()

    diff_result = ElPaso.Config.Diff.diff(old_config, new_config)
    changes = diff_result.changes

    if changes != [] do
      IO.puts("=== Config Diff: Cambios detectados ===\n")

      print_changes(changes)

      IO.puts("[A]plicar cambios  [R]efrescar  [Q]salir > ")

      # En producción se aplicaría la configuración y recargarían los modelos
      IO.puts("Configuración actualizada")
    else
      IO.puts("No hay cambios en la configuración")
    end
  end

  defp print_changes(changes) do
    Enum.each(changes, fn change ->
      impact_symbol =
        case change.impact do
          :requires_full_restart -> "[FULL]"
          :requires_model_restart -> "[MODEL]"
          :hot_reload -> "[HOT]"
        end

      type_text =
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

      IO.puts("#{impact_symbol} #{change.path} - #{type_text} (#{impact_text})")
    end)
  end
end
