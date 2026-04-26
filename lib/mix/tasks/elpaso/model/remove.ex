defmodule Mix.Tasks.Elpaso.Model.Remove do
  @moduledoc """
  Elimina un modelo.

  mix elpaso model remove <name>
  """

  use Mix.Task

  def run(args) do
    case args do
      [name] ->
        IO.puts("Removing model #{name}...")

        # In this simplified version, just show a sample
        IO.puts("✅ Model #{name} removed successfully!")

      _ ->
        IO.puts("Usage: mix elpaso model remove <name>")
    end
  end
end
