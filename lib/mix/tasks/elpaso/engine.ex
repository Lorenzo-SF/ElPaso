defmodule Mix.Tasks.Elpaso.Engine do
  @moduledoc """
  Comandos para gestión de motores.

  mix elpaso engine add <name> --type <type> --url <url>
  mix elpaso engine list
  mix elpaso engine remove <name>
  mix elpaso engine test <name>
  """

  use Mix.Task

  alias ElPaso.CLI.Output

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
        Output.error("Usage: mix elpaso engine <command>")
        Output.info("Commands:")
        Output.info("  add    Add a new engine")
        Output.info("  list   List all engines")
        Output.info("  remove Remove an engine")
        Output.info("  test   Test an engine")
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
        {:ok, _engine} ->
          Output.success("Motor '#{name}' creado exitosamente")

        {:error, reason} ->
          Output.error("Error al crear motor: #{reason}")
      end
    else
      Output.error(
        "Uso: mix elpaso engine add --name <name> --adapter <adapter> --base-url <url>"
      )
    end
  end

  defp list_engines() do
    case ElPaso.Domain.EngineManager.list_engines() do
      [] ->
        Output.warning("No hay motores registrados")

      engines ->
        rows =
          Enum.map(engines, fn engine ->
            [engine.name, engine.adapter, engine.base_url, to_string(engine.active)]
          end)

        Output.data_table(
          ["Name", "Adapter", "Base URL", "Active"],
          rows,
          headers_color: :cyan
        )
    end
  end

  defp remove_engine(name) do
    case ElPaso.Domain.EngineManager.delete_engine(name) do
      {:ok, _} ->
        Output.success("Motor '#{name}' eliminado exitosamente")

      {:error, reason} ->
        Output.error("Error al eliminar motor: #{reason}")
    end
  end

  defp test_engine(name) do
    case ElPaso.Domain.EngineManager.test_engine(name) do
      :ok ->
        Output.success("Motor '#{name}' probado exitosamente")

      {:error, reason} ->
        Output.error("Error al probar motor: #{reason}")
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
