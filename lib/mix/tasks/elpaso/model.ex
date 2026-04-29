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
      ["add" | rest] ->
        add_model(rest)

      ["list"] ->
        list_models()

      ["remove" | [name]] ->
        remove_model(name)

      ["start" | [name]] ->
        start_model(name)

      ["stop" | [name]] ->
        stop_model(name)

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

  defp add_model(args) do
    name = get_opt(args, :name)
    engine = get_opt(args, :engine)
    url = get_opt(args, :url)
    
    if name && engine && url do
      # Connect to the database and create model
      case ElPaso.Domain.ModelManager.create_model(%{
        name: name,
        engine_id: engine,
        url: url
      }) do
        {:ok, model} ->
          IO.puts("✅ Modelo '#{name}' creado exitosamente")
        {:error, reason} ->
          IO.puts("❌ Error al crear modelo: #{reason}")
      end
    else
      IO.puts("Uso: mix elpaso model add --name <name> --engine <engine> --url <url>")
    end
  end

  defp list_models() do
    case ElPaso.Domain.ModelManager.list_models() do
      models ->
        IO.puts("┌─────────┬──────────┬────────────────────┬────────┐")
        IO.puts("│ Name    │ Engine  │ URL               │ Active│")
        IO.puts("├─────────┼──────────┼────────────────────┼────────┤")
        Enum.each(models, fn model ->
          IO.puts("│ #{model.name} │ #{model.engine_id} │ #{model.url} │ #{model.active} │")
        end)
        IO.puts("└─────────┴──────────┴────────────────────┴────────┘")
      [] ->
        IO.puts("No hay modelos registrados")
    end
  end

  defp remove_model(name) do
    case ElPaso.Domain.ModelManager.delete_model(name) do
      :ok ->
        IO.puts("✅ Modelo '#{name}' eliminado exitosamente")
      {:error, reason} ->
        IO.puts("❌ Error al eliminar modelo: #{reason}")
    end
  end

  defp start_model(name) do
    case ElPaso.Domain.ModelManager.start_model(name) do
      :ok ->
        IO.puts("✅ Modelo '#{name}' iniciado exitosamente")
      {:error, reason} ->
        IO.puts("❌ Error al iniciar modelo: #{reason}")
    end
  end

  defp stop_model(name) do
    case ElPaso.Domain.ModelManager.stop_model(name) do
      :ok ->
        IO.puts("✅ Modelo '#{name}' detenido exitosamente")
      {:error, reason} ->
        IO.puts("❌ Error al detener modelo: #{reason}")
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
