defmodule Mix.Tasks.Elpaso.RegisterWrapper do
  @moduledoc """
  Lee tu wrapper `~/bin/llama-server` y registra en ElPaso los engines
  y modelos que tiene configurados.

  Uso:
      mix elpaso.register_wrapper [PATH_AL_WRAPPER]

  Si no se indica PATH_AL_WRAPPER, usa `~/bin/llama-server` por defecto.

  Inserta en la base de datos:
    - 1 Engine con el puerto/api-key del wrapper
    - N Models (uno por cada case definido en el wrapper)
    - N Personalities (creadas via migración seed)

  Es idempotente: si ya existen, los salta.
  """

  use Mix.Task

  alias ElPaso.CLI.Output
  alias ElPaso.Repo
  alias ElPaso.Models.{Engine, Model}

  @default_wrapper Path.expand("~/bin/llama-server")

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    wrapper = List.first(args) || @default_wrapper
    wrapper = Path.expand(wrapper)

    unless File.exists?(wrapper) do
      Mix.raise("Wrapper no encontrado: #{wrapper}")
    end

    Output.info("Leyendo wrapper: #{wrapper}")
    content = File.read!(wrapper)

    globals = parse_globals(content)
    models_cfg = parse_models(content)

    if models_cfg == [] do
      Mix.raise("No se encontraron modelos en el wrapper.")
    end

    Output.info("Puerto #{globals.port}, API key: #{globals.api_key}")
    Output.info("#{length(models_cfg)} modelo(s) detectado(s)")
    IO.puts("")

    engine = ensure_engine!(globals)

    Enum.each(models_cfg, fn cfg ->
      ensure_model!(engine, cfg)
    end)

    IO.puts("")
    Output.success("Registro completo.")
    Output.info("Engine : #{engine.name} → http://localhost:#{globals.port}/v1")
    Output.info("Arranca el servidor con:  llama-server <alias>")
    Output.info("Arranca ElPaso con:       elpaso server start")
  end

  # ---------------------------------------------------------------------------
  # Parsing del wrapper bash
  # ---------------------------------------------------------------------------

  defp parse_globals(content) do
    port = find(content, ~r/PORT="(\d+)"/, "8081") |> String.to_integer()
    api_key = find(content, ~r/API_KEY="([^"]+)"/, "sk-local")

    %{
      port: port,
      api_key: api_key,
      base_url: "http://localhost:#{port}/v1"
    }
  end

  defp parse_models(content) do
    # Extrae cada bloque case:  "thinker") ... ;;
    regex = ~r/"(\w+)"\)\s*\n(.*?);;/s

    Regex.scan(regex, content)
    |> Enum.map(fn [_, alias, block] ->
      alias = String.downcase(alias)

      model_path = find(block, ~r/MODEL_PATH="([^"]+)"/, "")
      ctx_size = find(block, ~r/CTX_SIZE=(\d+)/, "4096") |> String.to_integer()
      temp = find(block, ~r/--temp\s+([\d.]+)/, nil) |> parse_float()
      top_k = find(block, ~r/--top-k\s+(\d+)/, nil) |> parse_int()
      repeat_penalty = find(block, ~r/--repeat-penalty\s+([\d.]+)/, nil) |> parse_float()
      gpu_layers = find(block, ~r/--n-gpu-layers\s+(\d+)/, nil) |> parse_int()
      parallel = find(block, ~r/--parallel\s+(\d+)/, nil) |> parse_int()

      basename = Path.basename(model_path)

      %{
        alias: alias,
        model_path: model_path,
        basename: basename,
        ctx_size: ctx_size,
        temp: temp,
        top_k: top_k,
        repeat_penalty: repeat_penalty,
        gpu_layers: gpu_layers,
        parallel: parallel
      }
    end)
  end

  defp find(text, regex, default) do
    case Regex.run(regex, text) do
      [_, value] -> value
      _ -> default
    end
  end

  defp parse_float(nil), do: nil
  defp parse_float(s) when is_binary(s), do: String.to_float(s)
  defp parse_int(nil), do: nil
  defp parse_int(s) when is_binary(s), do: String.to_integer(s)

  # ---------------------------------------------------------------------------
  # DB inserts idempotentes
  # ---------------------------------------------------------------------------

  defp ensure_engine!(globals) do
    name = "llama-local"

    case Repo.get_by(Engine, name: name) do
      nil ->
        %Engine{}
        |> Engine.changeset(%{
          name: name,
          adapter: "llama_cpp",
          base_url: globals.base_url,
          api_key: globals.api_key,
          config: %{
            wrapper_path: @default_wrapper,
            port: globals.port
          },
          active: true
        })
        |> Repo.insert!()
        |> tap(fn e -> Output.success("Engine   : #{e.name} @ #{e.base_url}") end)

      existing ->
        Output.info("Engine   : #{existing.name} ya existe")
        existing
    end
  end

  defp ensure_model!(engine, cfg) do
    name = "local-#{cfg.alias}"

    task_affinity =
      case cfg.alias do
        "thinker" ->
          %{
            "code" => 0.7,
            "reasoning" => 0.95,
            "summarization" => 0.85,
            "question_answer" => 0.8,
            "creative" => 0.75,
            "translation" => 0.6,
            "unknown" => 0.7
          }

        "coder" ->
          %{
            "code" => 0.98,
            "reasoning" => 0.8,
            "summarization" => 0.5,
            "question_answer" => 0.6,
            "creative" => 0.4,
            "translation" => 0.3,
            "unknown" => 0.5
          }

        _ ->
          %{
            "code" => 0.5,
            "reasoning" => 0.5,
            "summarization" => 0.5,
            "question_answer" => 0.5,
            "creative" => 0.5,
            "translation" => 0.5,
            "unknown" => 0.5
          }
      end

    {complexity, cold_ms, desc} =
      case cfg.alias do
        "thinker" ->
          {1.0, 8000, "#{cfg.basename} — arquitectura, planificación, razonamiento"}

        "coder" ->
          {0.85, 5000, "#{cfg.basename} — código, debugging, completado"}

        _ ->
          {1.0, 5000, cfg.basename}
      end

    case Repo.get_by(Model, name: name) do
      nil ->
        %Model{}
        |> Model.changeset(%{
          name: name,
          engine_id: engine.id,
          url: engine.base_url,
          api_key: engine.api_key,
          active: true,
          max_tokens: cfg.ctx_size,
          temperature: cfg.temp || 0.7,
          top_p: 1.0,
          description: desc,
          task_affinity: task_affinity,
          complexity_ceiling: complexity,
          cold_start_estimate_ms: cold_ms,
          ram_mb: 22_000,
          vram_mb: 16_000
        })
        |> Repo.insert!()
        |> tap(fn m -> Output.success("Model    : #{m.name} (#{m.description})") end)

      existing ->
        Output.info("Model    : #{existing.name} ya existe")
        existing
    end
  end
end
