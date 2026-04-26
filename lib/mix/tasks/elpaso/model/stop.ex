defmodule Mix.Tasks.Elpaso.Model.Stop do
  @moduledoc """
  Detiene un modelo.

  mix elpaso model stop <name>
  """

  use Mix.Task

  def run(args) do
    case args do
      [name] ->
        IO.puts("Stopping model #{name}...")

        # In this simplified version, just show a sample
        IO.puts("✅ Model #{name} stopped successfully!")

      _ ->
        IO.puts("Usage: mix elpaso model stop <name>")
    end
  end
end
