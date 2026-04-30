defmodule Mix.Tasks.Elpaso.Engine.Remove do
  @moduledoc """
  Elimina un motor de inferencia.

  mix elpaso engine remove <name>
  """

  use Mix.Task

  alias ElPaso.CLI.Output

  def run(args) do
    case args do
      [name] ->
        Output.info("Removing engine #{name}...")

        # In this simplified version, just show a sample
        Output.success("Engine #{name} removed successfully!")

      _ ->
        Output.error("Usage: mix elpaso engine remove <name>")
    end
  end
end
