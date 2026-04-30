defmodule Mix.Tasks.Elpaso.Personality do
  @moduledoc """
  Comandos para gestión de personalidades.

  mix elpaso personality add <name> --system-prompt <prompt>
  mix elpaso personality list
  mix elpaso personality remove <name>
  mix elpaso personality show <name>
  """

  use Mix.Task

  alias ElPaso.CLI.Output

  def run(args) do
    case args do
      ["add" | rest] ->
        add_personality(rest)

      ["list"] ->
        list_personalities()

      ["remove" | [name]] ->
        remove_personality(name)

      ["show" | [name]] ->
        show_personality(name)

      _ ->
        Output.error("Usage: mix elpaso personality <command>")
        Output.info("Commands:")
        Output.info("  add    Add a new personality")
        Output.info("  list   List all personalities")
        Output.info("  remove Remove a personality")
        Output.info("  show   Show details of a personality")
    end
  end

  defp add_personality(args) do
    name = get_opt(args, :name)
    system_prompt = get_opt(args, :system_prompt)

    if name && system_prompt do
      # Connect to the database and create personality
      case ElPaso.Domain.PersonalityManager.create_personality(%{
             name: name,
             system_prompt: system_prompt
           }) do
        {:ok, _personality} ->
          Output.success("Personalidad '#{name}' creada exitosamente")

        {:error, reason} ->
          Output.error("Error al crear personalidad: #{reason}")
      end
    else
      Output.error("Uso: mix elpaso personality add --name <name> --system-prompt <prompt>")
    end
  end

  defp list_personalities() do
    case ElPaso.Domain.PersonalityManager.list_personalities() do
      [] ->
        Output.warning("No hay personalidades registradas")

      personalities ->
        rows =
          Enum.map(personalities, fn personality ->
            prompt = String.slice(personality.system_prompt, 0, 30) <> "..."
            [personality.name, prompt]
          end)

        Output.data_table(
          ["Name", "System Prompt"],
          rows,
          headers_color: :cyan
        )
    end
  end

  defp remove_personality(name) do
    case ElPaso.Domain.PersonalityManager.delete_personality(name) do
      :ok ->
        Output.success("Personalidad '#{name}' eliminada exitosamente")

      {:error, reason} ->
        Output.error("Error al eliminar personalidad: #{reason}")
    end
  end

  defp show_personality(name) do
    case ElPaso.Domain.PersonalityManager.get_personality(name) do
      nil ->
        Output.error("Personalidad no encontrada")

      personality ->
        Output.section("Personalidad: #{personality.name}")
        Output.info("System Prompt: #{personality.system_prompt}")
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
