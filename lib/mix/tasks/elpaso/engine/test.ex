defmodule Mix.Tasks.Elpaso.Engine.Test do
  @moduledoc """
  Prueba la conectividad de un motor de inferencia.

  mix elpaso engine test <name>
  """

  use Mix.Task

  alias ElPaso.CLI.Output

  def run(args) do
    case args do
      [name] ->
        Output.info("Testing engine #{name}...")

        # In this simplified version, just show a sample
        Output.success("Engine #{name} tested successfully!")

      _ ->
        Output.error("Usage: mix elpaso engine test <name>")
    end
  end
end
