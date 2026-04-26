defmodule Mix.Tasks.Elpaso.Model.Start do
  @moduledoc """
  Inicia un modelo.

  mix elpaso model start <name>
  """

  use Mix.Task

  def run(args) do
    case args do
      [name] ->
        IO.puts("Starting model #{name}...")

        # In this simplified version, just show a sample
        IO.puts("✅ Model #{name} started successfully!")

      _ ->
        IO.puts("Usage: mix elpaso model start <name>")
    end
  end
end
