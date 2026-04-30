defmodule Mix.Tasks.Elpaso.Model.Start do
  @moduledoc """
  Inicia un modelo.

  mix elpaso model start <name>
  """

  use Mix.Task

  alias ElPaso.CLI.Output

  def run(args) do
    case args do
      [name] ->
        Output.info("Starting model #{name}...")

        # In this simplified version, just show a sample
        Output.success("Model #{name} started successfully!")

      _ ->
        Output.error("Usage: mix elpaso model start <name>")
    end
  end
end
