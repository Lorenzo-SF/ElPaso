defmodule Mix.Tasks.Elpaso.Model.Stop do
  @moduledoc """
  Detiene un modelo.

  mix elpaso model stop <name>
  """

  use Mix.Task

  alias ElPaso.CLI.Output

  def run(args) do
    case args do
      [name] ->
        Output.info("Stopping model #{name}...")

        # In this simplified version, just show a sample
        Output.success("Model #{name} stopped successfully!")

      _ ->
        Output.error("Usage: mix elpaso model stop <name>")
    end
  end
end
