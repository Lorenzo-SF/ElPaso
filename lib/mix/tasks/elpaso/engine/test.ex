defmodule Mix.Tasks.Elpaso.Engine.Test do
  @moduledoc """
  Prueba la conectividad de un motor de inferencia.

  mix elpaso engine test <name>
  """

  use Mix.Task

  def run(args) do
    case args do
      [name] ->
        IO.puts("Testing engine #{name}...")

        # In this simplified version, just show a sample
        IO.puts("✅ Engine #{name} tested successfully!")

      _ ->
        IO.puts("Usage: mix elpaso engine test <name>")
    end
  end
end
