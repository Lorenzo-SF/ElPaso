defmodule Mix.Tasks.Elpaso.Engine do
  @moduledoc """
  Comandos para gestión de motores.

  mix elpaso engine add <name> --type <type> --url <url>
  mix elpaso engine list
  mix elpaso engine remove <name>
  mix elpaso engine test <name>
  """

  use Mix.Task

  def run(args) do
    case args do
      ["add" | _rest] ->
        IO.puts("Engine add command not yet implemented")

      ["list"] ->
        IO.puts("Engine list command not yet implemented")

      ["remove" | _name] ->
        IO.puts("Engine remove command not yet implemented")

      ["test" | _name] ->
        IO.puts("Engine test command not yet implemented")

      _ ->
        IO.puts("Usage: mix elpaso engine <command>")
        IO.puts("Commands:")
        IO.puts("  add    Add a new engine")
        IO.puts("  list     List all engines")
        IO.puts("  remove Remove an engine")
        IO.puts("  test   Test an engine")
    end
  end
end
