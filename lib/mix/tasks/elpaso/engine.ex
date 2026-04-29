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
      ["add" | rest] ->
        add_engine(rest)

      ["list"] ->
        list_engines()

      ["remove" | [name]] ->
        remove_engine(name)

      ["test" | [name]] ->
        test_engine(name)

      _ ->
        IO.puts("Usage: mix elpaso engine <command>")
        IO.puts("Commands:")
        IO.puts("  add    Add a new engine")
        IO.puts("  list     List all engines")
        IO.puts("  remove Remove an engine")
        IO.puts("  test   Test an engine")
    end
  end

  defp add_engine(args) do
    name = get_opt(args, :name)
    adapter = get_opt(args, :adapter)
    base_url = get_opt(args, :base_url)
    
    if name && adapter && base_url do
      # Connect to the database and create engine
      case ElPaso.Domain.EngineManager.create_engine(%{
        name: name,
        adapter: adapter,
        base_url: base_url
      }) do
        {:ok, engine} ->
          IO.puts("✅ Motor '#{name}' creado exitosamente")
        {:error, reason} ->
          IO.puts("❌ Error al crear motor: #{reason}")
      end
    else
      IO.puts("Uso: mix elpaso engine add --name <name> --adapter <adapter> --base-url <url>")
    end
  end

  defp list_engines() do
    case ElPaso.Domain.EngineManager.list_engines() do
      engines ->
        IO.puts("┌───────────┬─────────┬─────────────────────┬────────┐")
        IO.puts("│ Name     │ Adapter │ Base URL           │ Active│")
        IO.puts("├───────────┼─────────┼─────────────────────┼────────┤")
        Enum.each(engines, fn engine ->
          IO.puts("│ #{engine.name} │ #{engine.adapter} │ #{engine.base_url} │ #{engine.active} │")
        end)
        IO.puts("└───────────┴─────────┴─────────────────────┴────────┘")
      [] ->
        IO.puts("No hay motores registrados")
    end
  end

  defp remove_engine(name) do
    case ElPaso.Domain.EngineManager.delete_engine(name) do
      :ok ->
        IO.puts("✅ Motor '#{name}' eliminado exitosamente")
      {:error, reason} ->
        IO.puts("❌ Error al eliminar motor: #{reason}")
    end
  end

  defp test_engine(name) do
    case ElPaso.Domain.EngineManager.test_engine(name) do
      :ok ->
        IO.puts("✅ Motor '#{name}' probado exitosamente")
      {:error, reason} ->
        IO.puts("❌ Error al probar motor: #{reason}")
    end
  end

  defp get_opt(args, key) do
    key_str = Atom.to_string(key)
    Enum.find_value(args, fn arg ->
      case String.split(arg, "=", parts: 2) do
        [^key_str, v] -> v
        _ -> false
      end
    end)
  end
end
