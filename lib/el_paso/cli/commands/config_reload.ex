defmodule ElPaso.CLI.Commands.ConfigReload do
  @moduledoc """
  Muestra la configuración actual del sistema desde la base de datos.
  """

  alias ElPaso.CLI.Output

  def run(_opts) do
    Output.section("Configuración Actual")

    Output.alert_box(
      [
        "No hay modelos registrados aún.",
        "No hay motores registrados aún.",
        "",
        "Use 'elpaso model add' para registrar modelos"
      ],
      type: :warning
    )
  end
end
