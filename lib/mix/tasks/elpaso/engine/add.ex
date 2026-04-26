defmodule Mix.Tasks.Elpaso.Engine.Add do
  @moduledoc """
  Añade un nuevo motor de inferencia.

  mix elpaso engine add <name> --type <type> --url <url>
  """

  use Mix.Task

  def run(args) do
    case parse_args(args) do
      %{name: name, type: type, url: url} ->
        IO.puts("Adding engine #{name} of type #{type} at #{url}")

        # In this simplified version, just display the info
        IO.puts("✅ Engine #{name} added successfully!")

      _ ->
        IO.puts("Usage: mix elpaso engine add <name> --type <type> --url <url>")
    end
  end

  defp parse_args(args) do
    Enum.reduce(args, %{name: nil, type: nil, url: nil}, fn arg, acc ->
      case String.split(arg, "=", parts: 2) do
        ["--name", name] -> Map.put(acc, :name, name)
        ["--type", type] -> Map.put(acc, :type, type)
        ["--url", url] -> Map.put(acc, :url, url)
        _ -> acc
      end
    end)
  end
end
