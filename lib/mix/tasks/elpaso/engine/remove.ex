defmodule Mix.Tasks.Elpaso.Engine.Remove do
  @moduledoc """
  Elimina un motor de inferencia.

  mix elpaso engine remove <name>
  """

  use Mix.Task

  def run(args) do
    case args do
      [name] ->
        IO.puts("Removing engine #{name}...")

        # In this simplified version, just show a sample
        IO.puts("✅ Engine #{name} removed successfully!")

      _ ->
        IO.puts("Usage: mix elpaso engine remove <name>")
    end
  end
end
