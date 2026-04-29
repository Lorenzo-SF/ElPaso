defmodule Mix.Tasks.Elpaso.Personality do
  @moduledoc """
  Comandos para gestión de personalidades.

  mix elpaso personality add <name> --system-prompt <prompt>
  mix elpaso personality list
  mix elpaso personality remove <name>
  mix elpaso personality show <name>
  """

  use Mix.Task

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
        IO.puts("Usage: mix elpaso personality <command>")
        IO.puts("Commands:")
        IO.puts("  add    Add a new personality")
        IO.puts("  list   List all personalities")
        IO.puts("  remove Remove a personality")
        IO.puts("  show   Show details of a personality")
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
        {:ok, personality} ->
          IO.puts("✅ Personalidad '#{name}' creada exitosamente")
        {:error, reason} ->
          IO.puts("❌ Error al crear personalidad: #{reason}")
      end
    else
      IO.puts("Uso: mix elpaso personality add --name <name> --system-prompt <prompt>")
    end
  end

  defp list_personalities() do
    case ElPaso.Domain.PersonalityManager.list_personalities() do
      personalities ->
        IO.puts("┌─────────┬─────────────────────┐")
        IO.puts("│ Name    │ System Prompt     │")
        IO.puts("├─────────┼─────────────────────┤")
        Enum.each(personalities, fn personality ->
          IO.puts("│ #{personality.name} │ #{String.slice(personality.system_prompt, 0, 20)}... │")
        end)
        IO.puts("└─────────┴─────────────────────┘")
      [] ->
        IO.puts("No hay personalidades registradas")
    end
  end

  defp remove_personality(name) do
    case ElPaso.Domain.PersonalityManager.delete_personality(name) do
      :ok ->
        IO.puts("✅ Personalidad '#{name}' eliminada exitosamente")
      {:error, reason} ->
        IO.puts("❌ Error al eliminar personalidad: #{reason}")
    end
  end

  defp show_personality(name) do
    case ElPaso.Domain.PersonalityManager.get_personality(name) do
      nil ->
        IO.puts("❌ Personalidad no encontrada")
      personality ->
        IO.puts("Personalidad: #{personality.name}")
        IO.puts("  System Prompt: #{personality.system_prompt}")
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