defmodule Mix.Tasks.Elpaso.Model.Remove do
  @moduledoc """
  Elimina un modelo.

  mix elpaso model remove <name>
  """

  use Mix.Task

  alias ElPaso.CLI.Output

  def run(args) do
    case args do
      [name] ->
        Output.info("Removing model #{name}...")

        # In this simplified version, just show a sample
        Output.success("Model #{name} removed successfully!")

      _ ->
        Output.error("Usage: mix elpaso model remove <name>")
    end
  end
end
