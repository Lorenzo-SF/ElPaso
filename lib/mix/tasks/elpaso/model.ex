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

  alias ElPaso.CLI.Output

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
        Output.error("Usage: mix elpaso model <command>")
        Output.info("Commands:")
        Output.info("  add    Add a new model")
        Output.info("  list   List all models")
        Output.info("  remove Remove a model")
        Output.info("  start  Start a model")
        Output.info("  stop   Stop a model")
    end
  end

  defp add_model(args) do
    name = get_opt(args, :name)
    engine_name = get_opt(args, :engine)
    url = get_opt(args, :url)

    if name && engine_name && url do
      # Resolve engine name to UUID
      engine_id =
        case ElPaso.Domain.EngineManager.get_engine(engine_name) do
          nil -> nil
          engine -> engine.id
        end

      if engine_id do
        case ElPaso.Domain.ModelManager.create_model(%{
               name: name,
               engine_id: engine_id,
               url: url
             }) do
          {:ok, _model} ->
            Output.success("Modelo '#{name}' creado exitosamente")

          {:error, reason} ->
            Output.error("Error al crear modelo: #{reason}")
        end
      else
        Output.error("Motor '#{engine_name}' no encontrado")
      end
    else
      Output.error("Uso: mix elpaso model add --name <name> --engine <engine> --url <url>")
    end
  end

  defp list_models() do
    case ElPaso.Domain.ModelManager.list_models() do
      [] ->
        Output.warning("No hay modelos registrados")

      models ->
        rows =
          Enum.map(models, fn model ->
            [model.name, model.engine_id, model.url, to_string(model.active)]
          end)

        Output.data_table(
          ["Name", "Engine", "URL", "Active"],
          rows,
          headers_color: :cyan
        )
    end
  end

  defp remove_model(name) do
    case ElPaso.Domain.ModelManager.delete_model(name) do
      {:ok, _} ->
        Output.success("Modelo '#{name}' eliminado exitosamente")

      {:error, reason} ->
        Output.error("Error al eliminar modelo: #{format_error(reason)}")
    end
  end

  defp start_model(name) do
    case ElPaso.Domain.ModelManager.start_model(name) do
      {:ok, _} ->
        Output.success("Modelo '#{name}' iniciado exitosamente")

      {:error, reason} ->
        Output.error("Error al iniciar modelo: #{format_error(reason)}")
    end
  end

  defp stop_model(name) do
    case ElPaso.Domain.ModelManager.stop_model(name) do
      {:ok, _} ->
        Output.success("Modelo '#{name}' detenido exitosamente")

      {:error, reason} ->
        Output.error("Error al detener modelo: #{format_error(reason)}")
    end
  end

  defp format_error(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

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
