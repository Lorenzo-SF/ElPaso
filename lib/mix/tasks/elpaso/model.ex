defmodule Mix.Tasks.Elpaso.Model do
  @moduledoc """
  Comandos para gestión de modelos.

  mix elpaso model add <name> --engine <engine> --url <url>
  mix elpaso model list
  mix elpaso model remove <name>
  mix elpaso model start <name>
  mix elpaso model stop <name>
  """

  use Mix.Task

  def run(args) do
    case args do
      ["add" | _rest] ->
        IO.puts("Model add command not yet implemented")

      ["list"] ->
        IO.puts("Model list command not yet implemented")

      ["remove" | _name] ->
        IO.puts("Model remove command not yet implemented")

      ["start" | _name] ->
        IO.puts("Model start command not yet implemented")

      ["stop" | _name] ->
        IO.puts("Model stop command not yet implemented")

      _ ->
        IO.puts("Usage: mix elpaso model <command>")
        IO.puts("Commands:")
        IO.puts("  add    Add a new model")
        IO.puts("  list   List all models")
        IO.puts("  remove Remove a model")
        IO.puts("  start Start a model")
        IO.puts("  stop   Stop a model")
    end
  end
end
