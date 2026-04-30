defmodule ElPaso.CLI.Commands.ModelAdd do
  @moduledoc """
  Comando para añadir un nuevo modelo a la configuración.
  """

  alias ElPaso.CLI.Output

  def run(args) do
    Output.info(
      "Usage: elpaso model add --name <name> --engine <engine> --url <url> [--api-key <key>] [--description <desc>] [--active true|false] [--max-tokens <num>]"
    )

    if Enum.member?(args, "--help") or Enum.member?(args, "-h") do
      Output.section("elpaso model add")

      IO.puts("""
      Registra un nuevo modelo de inferencia en la base de datos.

      Opciones:
        --name          Nombre del modelo (requerido)
        --engine      ID o nombre del motor (requerido)  
        --url         URL del endpoint de inferencia (requerido)
        --api-key       API key para autenticación (opcional)
        --description Descripción del modelo (opcional)
        --active      Si está activo (por defecto: true)
        --max-tokens Máximo número de tokens (opcional)

      Ejemplo:
        elpaso model add \\
          --name llama3 \\
          --engine ollama \\
          --url http://localhost:11434/v1 \\
          --api-key no-api-key-required
      """)
    else
      Output.info("Use 'elpaso model add --help' para más información.")
    end
  end
end
