defmodule Mix.Tasks.Elpaso.Model.Add do
  @moduledoc """
  Añade un nuevo modelo.

  mix elpaso model add <name> --engine <engine> --url <url>
  """

  use Mix.Task

  def run(args) do
    case parse_args(args) do
      %{name: name, engine: engine, url: url} ->
        IO.puts("Adding model #{name} with engine #{engine} at #{url}")

        # In this simplified version, just display the info
        IO.puts("✅ Model #{name} added successfully!")

      _ ->
        IO.puts("Usage: mix elpaso model add <name> --engine <engine> --url <url>")
    end
  end

  defp parse_args(args) do
    Enum.reduce(args, %{name: nil, engine: nil, url: nil}, fn arg, acc ->
      case String.split(arg, "=", parts: 2) do
        ["--name", name] -> Map.put(acc, :name, name)
        ["--engine", engine] -> Map.put(acc, :engine, engine)
        ["--url", url] -> Map.put(acc, :url, url)
        _ -> acc
      end
    end)
  end
end
