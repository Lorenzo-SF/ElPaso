defmodule Mix.Tasks.Elpaso.SetupLocal do
  @moduledoc """
  Configura ElPaso para usar los dos modelos locales servidos por llama.cpp.

  Este task inserta en la base de datos:
    - 2 engines (thinker en :8081, coder en :8082)
    - 2 models (Qwen Thinker y Qwen Coder)
    - 2 profiles (por defecto, uno por modelo)

  Uso:
      mix elpaso.setup_local

  Requiere:
      - PostgreSQL corriendo y accesible
      - llama-server thinker en localhost:8081
      - llama-server coder  en localhost:8082
  """

  use Mix.Task

  alias ElPaso.Repo
  alias ElPaso.Models.{Engine, Model, Profile}

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("⚙️  Configurando engines y modelos locales...")

    # --- Engines ---
    thinker_engine = ensure_engine!(%{
      name: "llama-local-thinker",
      adapter: "llama_server",
      base_url: "http://localhost:8081/v1",
      api_key: "sk-local",
      config: %{
        model_alias: "thinker",
        ctx_size: 128_000,
        gpu_layers: 22,
        batch_size: 4096,
        ubatch_size: 2048,
        temp: 0.4,
        repeat_penalty: 1.05,
        keep: 16_384
      },
      active: true
    })

    coder_engine = ensure_engine!(%{
      name: "llama-local-coder",
      adapter: "llama_server",
      base_url: "http://localhost:8082/v1",
      api_key: "sk-local",
      config: %{
        model_alias: "coder",
        ctx_size: 48_000,
        gpu_layers: 49,
        batch_size: 4096,
        ubatch_size: 2048,
        temp: 0.3,
        top_k: 20,
        repeat_penalty: 1.05,
        keep: 8192,
        parallel: 2
      },
      active: true
    })

    # --- Models ---
    thinker_model = ensure_model!(%{
      name: "local-thinker",
      engine_id: thinker_engine.id,
      url: "http://localhost:8081/v1",
      api_key: "sk-local",
      active: true,
      max_tokens: 32_768,
      temperature: 0.4,
      top_p: 1.0,
      description: "Qwen3.6-35B-A3B Q4_K_M — arquitectura, planificación, razonamiento",
      task_affinity: %{
        "code" => 0.7,
        "reasoning" => 0.95,
        "summarization" => 0.85,
        "question_answer" => 0.8,
        "creative" => 0.75,
        "translation" => 0.6,
        "unknown" => 0.7
      },
      complexity_ceiling: 1.0,
      cold_start_estimate_ms: 8000,
      ram_mb: 22_000,
      vram_mb: 16_000
    })

    coder_model = ensure_model!(%{
      name: "local-coder",
      engine_id: coder_engine.id,
      url: "http://localhost:8082/v1",
      api_key: "sk-local",
      active: true,
      max_tokens: 16_384,
      temperature: 0.3,
      top_p: 1.0,
      description: "Qwen3-Coder-30B-A3B Q3_K_XL — código, debugging, completado",
      task_affinity: %{
        "code" => 0.98,
        "reasoning" => 0.8,
        "summarization" => 0.5,
        "question_answer" => 0.6,
        "creative" => 0.4,
        "translation" => 0.3,
        "unknown" => 0.5
      },
      complexity_ceiling: 0.85,
      cold_start_estimate_ms: 5000,
      ram_mb: 18_000,
      vram_mb: 16_000
    })

    # --- Profiles ---
    ensure_profile!(%{
      name: "thinker-default",
      model_id: thinker_model.id,
      engine_id: thinker_engine.id,
      config: %{},
      active: true,
      description: "Perfil por defecto para razonamiento y arquitectura"
    })

    ensure_profile!(%{
      name: "coder-default",
      model_id: coder_model.id,
      engine_id: coder_engine.id,
      config: %{},
      active: true,
      description: "Perfil por defecto para desarrollo y código"
    })

    IO.puts("")
    IO.puts("✅ Configuración local completada.")
    IO.puts("")
    IO.puts("Endpoints disponibles:")
    IO.puts("  • Thinker → http://localhost:8081/v1  (model: local-thinker)")
    IO.puts("  • Coder   → http://localhost:8082/v1  (model: local-coder)")
    IO.puts("")
    IO.puts("Arranca ElPaso con:  mix run --no-halt")
    IO.puts("O genera el escript:  MIX_ENV=prod mix gen")
    :ok
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp ensure_engine!(attrs) do
    case Repo.get_by(Engine, name: attrs.name) do
      nil ->
        %Engine{}
        |> Engine.changeset(attrs)
        |> Repo.insert!()
        |> tap(fn e -> IO.puts("  ➕ Engine   : #{e.name} @ #{e.base_url}") end)

      existing ->
        IO.puts("  ℹ️  Engine   : #{existing.name} ya existe")
        existing
    end
  end

  defp ensure_model!(attrs) do
    case Repo.get_by(Model, name: attrs.name) do
      nil ->
        %Model{}
        |> Model.changeset(attrs)
        |> Repo.insert!()
        |> tap(fn m -> IO.puts("  ➕ Model    : #{m.name} → #{m.description}") end)

      existing ->
        IO.puts("  ℹ️  Model    : #{existing.name} ya existe")
        existing
    end
  end

  defp ensure_profile!(attrs) do
    case Repo.get_by(Profile, name: attrs.name) do
      nil ->
        %Profile{}
        |> Profile.changeset(attrs)
        |> Repo.insert!()
        |> tap(fn p -> IO.puts("  ➕ Profile  : #{p.name}") end)

      existing ->
        IO.puts("  ℹ️  Profile  : #{existing.name} ya existe")
        existing
    end
  end
end
