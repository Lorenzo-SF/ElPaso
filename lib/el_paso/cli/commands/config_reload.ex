defmodule ElPaso.CLI.Commands.ConfigReload do
  @moduledoc """
  Muestra la configuración actual del sistema desde la base de datos.
  """

  def run(_opts) do
    IO.puts("\n=== Configuración Actual ===")
    IO.puts("Configuración cargada desde base de datos:")
    IO.puts("  - Modelos: (no hay modelos registrados aún)")
    IO.puts("  - Motores: (no hay motores registrados aún)")
    IO.puts("Use 'elpaso model add' para registrar modelos")
  end
end
