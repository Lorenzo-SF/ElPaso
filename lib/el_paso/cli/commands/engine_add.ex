defmodule ElPaso.CLI.Commands.EngineAdd do
  @moduledoc """
  Comando para añadir un nuevo motor de inferencia.
  """

  alias ElPaso.CLI.Output

  def run(args) do
    Output.info(
      "Usage: elpaso engine add --name <name> --adapter <adapter> --base-url <url> [--api-key <key>] [--description <desc>] [--active true|false]"
    )

    if Enum.member?(args, "--help") or Enum.member?(args, "-h") do
      Output.section("elpaso engine add")

      IO.puts("""
      Registra un nuevo motor de inferencia en la base de datos.

      Opciones:
        --name          Nombre del motor (requerido)
        --adapter       Tipo de adaptador (requerido)  
        --base-url      URL base del motor (requerido)
        --api-key     API key para autenticación (opcional)
        --description   Descripción del motor (opcional)
        --active        Si está activo (por defecto: true)

      Ejemplo:
        elpaso engine add \\
          --name ollama \\
          --adapter ollama \\
          --base-url http://localhost:11434/v1
      """)
    else
      Output.info("Use 'elpaso engine add --help' para más información.")
    end
  end
end
