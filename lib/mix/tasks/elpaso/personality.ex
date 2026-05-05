defmodule Mix.Tasks.Elpaso.Personality do
  @moduledoc """
  Gestión de personalidades (skills/roles) — el MoE manual de ElPaso.

  Cada personalidad vincula un model + engine con triggers de activación:

    mix elpaso personality add <name> \\
      --model <model_name> --engine <engine_name> \\
      --system-prompt "<prompt>" \\
      --keywords "refactoriza,implementa,test" \\
      --task-types "code,debug" \\
      --priority 10 \\
      --default

    mix elpaso personality list
    mix elpaso personality remove <name>
    mix elpaso personality show <name>
  """

  use Mix.Task

  alias ElPaso.CLI.Output
  alias ElPaso.Domain.PersonalityManager
  alias ElPaso.Repo

  def run(args) do
    case args do
      ["add" | rest] -> add_personality(rest)
      ["list"] -> list_personalities()
      ["remove" | [name]] -> remove_personality(name)
      ["show" | [name]] -> show_personality(name)
      _ ->
        Output.error("Usage: mix elpaso personality <add|list|remove|show>")
        Output.info("  add <name> --model <m> --engine <e> --system-prompt <p> [--keywords k1,k2] [--task-types t1,t2] [--priority N] [--default]")
    end
  end

  defp add_personality(args) do
    name = get_opt(args, "name")
    system_prompt = get_opt(args, "system-prompt")
    model_name = get_opt(args, "model")
    engine_name = get_opt(args, "engine")

    if name && system_prompt do
      # Resolver model_id y engine_id
      model = if model_name, do: Repo.get_by(ElPaso.Models.Model, name: model_name)
      engine = if engine_name, do: Repo.get_by(ElPaso.Models.Engine, name: engine_name)

      keywords = parse_list(get_opt(args, "keywords"))
      task_types = parse_list(get_opt(args, "task-types"))
      priority = parse_int(get_opt(args, "priority"), 0)
      is_default = "--default" in args

      attrs = %{
        name: name,
        system_prompt: system_prompt,
        model_id: model && model.id,
        engine_id: engine && engine.id,
        trigger_keywords: keywords,
        trigger_task_types: task_types,
        priority: priority,
        is_default: is_default,
        description: get_opt(args, "description")
      }

      case PersonalityManager.create_personality(attrs) do
        {:ok, p} ->
          Output.success("Personalidad '#{p.name}' creada (priority: #{p.priority}#{if p.is_default, do: ", default"})")

        {:error, changeset} ->
          errors = Enum.map(changeset.errors, fn {k, {msg, _}} -> "#{k}: #{msg}" end)
          Output.error("Error: #{Enum.join(errors, ", ")}")
      end
    else
      Output.error("--name y --system-prompt son obligatorios")
    end
  end

  defp list_personalities do
    personalities = PersonalityManager.list_personalities()

    if personalities == [] do
      Output.warning("No hay personalidades registradas")
    else
      rows = Enum.map(personalities, fn p ->
        prompt = String.slice(p.system_prompt, 0, 40) <> "..."
        triggers =
          cond do
            not Enum.empty?(p.trigger_keywords || []) ->
              p.trigger_keywords |> Enum.take(3) |> Enum.join(",") |> Kernel.<>("…")
            p.is_default -> "★ default"
            true -> "—"
          end
        model_name = if p.model, do: p.model.name, else: "—"
        [p.name, model_name, to_string(p.priority), triggers, prompt]
      end)

      Output.data_table(
        ["Name", "Model", "Priority", "Triggers", "System Prompt"],
        rows,
        headers_color: :cyan
      )
    end
  end

  defp remove_personality(name) do
    case PersonalityManager.delete_personality(name) do
      {:ok, _} -> Output.success("Personalidad '#{name}' eliminada")
      {:error, reason} -> Output.error("Error: #{reason}")
    end
  end

  defp show_personality(name) do
    case PersonalityManager.get_personality(name) do
      nil -> Output.error("Personalidad no encontrada")
      p ->
        Output.section("Personalidad: #{p.name}")
        Output.info("  Description: #{p.description || "—"}")
        Output.info("  Model: #{p.model && p.model.name || "—"}")
        Output.info("  Engine: #{p.engine && p.engine.name || "—"}")
        Output.info("  Priority: #{p.priority}  |  Default: #{p.is_default}")
        Output.info("  Trigger keywords: #{Enum.join(p.trigger_keywords || [], ", ")}")
        Output.info("  Trigger task types: #{Enum.join(p.trigger_task_types || [], ", ")}")
        Output.info("  System prompt: #{p.system_prompt}")
    end
  end

  defp get_opt(args, key) do
    prefix = "--#{key}="
    Enum.find_value(args, fn arg ->
      if String.starts_with?(arg, prefix), do: String.replace_prefix(arg, prefix, ""), else: false
    end)
  end

  defp parse_list(nil), do: []
  defp parse_list(str), do: String.split(str, ",", trim: true) |> Enum.map(&String.trim/1)

  defp parse_int(nil, default), do: default
  defp parse_int(str, _default) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> 0
    end
  end
end
