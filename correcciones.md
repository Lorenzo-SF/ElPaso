═══════════════════════════════════════════════════════════════════════════════
ELPASO — PROMPT DEFINITIVO: CORRECCIÓN, COMPLETADO Y PREPARACIÓN PARA USO REAL
Runtime: Elixir 1.19.5-otp-28 | Infra local: llama-server en localhost:8081
═══════════════════════════════════════════════════════════════════════════════

Lee este documento completo antes de tocar una línea de código.
Trabaja sección a sección en el orden indicado.
No pases a la siguiente sección hasta que la actual compile y sus criterios pasan.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 0 — DIAGNÓSTICO: qué está roto, qué está a medias, qué sobra
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ROTO (impide arrancar):
  - Config.Loader.get() hace raise si no hay ENVs → Application.start/2 explota
  - Config.cluster_enabled?() llama Config.Loader.get() → mismo crash
  - Application no tiene ElPaso.Repo ni Finch en el árbol OTP
  - Application llama ModelDownloaderRegistry.init() que no existe como módulo
  - el_paso.ex tiene hello/world de mix new

A MEDIAS (no hace nada real):
  - Config system entero: ignora elpaso.conf, solo lee 2 ENVs hardcodeadas
  - Context.Storage: todos los métodos devuelven datos falsos o vacíos
  - Context.Manager.reload_session: siempre {:error, :not_found}
  - Domain.ModelManager: DynamicSupervisor vacío que devuelve [] para todo
  - Engine.Dispatcher: ignora model_id, devuelve "response" hardcodeado
  - Engine.Ollama: stub de 3 líneas
  - SummarizationWorker.generate_summary: devuelve "Resumen generado"
  - HTTP.Server: no tiene POST /v1/chat/completions, GET /v1/models, GET /health
  - HTTP.Server.run_anthropic_pipeline: devuelve "Response to: #{prompt}"
  - HTTP.Server.run_anthropic_stream: Process.sleep(50) con palabras del prompt
  - WebSocketHandler.process_chat_stream: simula con Process.sleep(500)
  - HTTP.InternalClient.chat: devuelve {:ok, "response"}
  - Dashboard /api/state: devuelve todo a cero
  - Event.Supervisor: children vacíos
  - Schemas Ecto: tipos incorrectos (sessions usa :string para id en vez de :binary_id)
  - CLI: no tiene comandos para registrar motores/modelos

AUSENTE (mencionado en doc, no existe):
  - POST /v1/chat/completions (endpoint principal)
  - GET /health, GET /v1/models
  - Migraciones Ecto (las 4 tablas)
  - Engine.LlamaServer, Engine.OpenAI, Engine.VLLM, Engine.Anthropic
  - Domain.ModelWorker, Domain.ModelSupervisor, Domain.ModelPool, Domain.ModelRegistry
  - Config.Schema, Config.Merger, Config.EnvironmentDetector
  - Context.Manager.append_turn, get_context_layers, set_summarization_flag
  - Context.Builder.BuiltPrompt struct (referenciado en Engine behaviour)
  - Lógica de registro de motores/modelos vía CLI
  - MCP/Skills/Agents support
  - Wrapper AirLLM
  - Help system completo en inglés
  - README.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 1 — HACER ARRANCAR: CONFIG SIN CRASH Y APPLICATION LIMPIO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 1.1 — Reescribir Config.Loader como GenServer persistente

El `Config.Loader.get()` actual hace `raise` si no hay ENVs. Esto debe
eliminarse completamente. Reemplazar `lib/el_paso/config.ex` con:

```elixir
defmodule ElPaso.Config do
  @moduledoc false
  # Fachada de funciones de conveniencia sobre Config.Loader
end

defmodule ElPaso.Config.Loader do
  @moduledoc """
  Manages ElPaso runtime configuration.

  Configuration is loaded from `~/.config/elpaso/elpaso.conf` (JSON).
  If the file doesn't exist, sensible defaults are used and the system
  starts normally. Use `mix elpaso init` or `mix elpaso engine add` to
  create and populate the configuration file.
  """
  use GenServer
  require Logger

  @config_path Path.expand("~/.config/elpaso/elpaso.conf")

  # ── Public API ────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns current config. Never raises. Returns defaults if not loaded."
  def get do
    case GenServer.call(__MODULE__, :get) do
      nil    -> default_config()
      config -> config
    end
  catch
    :exit, _ -> default_config()
  end

  @doc "Reloads config from disk."
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  @doc "Returns a specific engine config map by engine alias."
  def get_engine(engine_alias) when is_binary(engine_alias) do
    config = get()
    case Map.get(config.engines || %{}, engine_alias) do
      nil -> {:error, :engine_not_found}
      eng -> {:ok, eng}
    end
  end

  @doc "Returns a model config map by model alias."
  def get_model(model_alias) when is_binary(model_alias) do
    config = get()
    case Enum.find(config.models || [], &(&1.alias == model_alias)) do
      nil   -> {:error, :model_not_found}
      model -> {:ok, model}
    end
  end

  @doc "Returns all registered models."
  def list_models do
    get().models || []
  end

  @doc "Returns all registered engines."
  def list_engines do
    Map.values(get().engines || %{})
  end

  @doc "Returns affinity value for model+task_type. Defaults to 0.5."
  def get_affinity(model_alias, task_type) do
    model = case get_model(model_alias) do
      {:ok, m} -> m
      _        -> %{}
    end
    get_in(model, [:routing, :task_affinity, task_type]) || 0.5
  end

  @doc "Updates affinity for model+task_type. In-memory only until next reload."
  def update_affinity(model_alias, task_type, new_value) do
    GenServer.call(__MODULE__, {:update_affinity, model_alias, task_type, new_value})
  end

  @doc "Saves current in-memory config to disk."
  def save do
    GenServer.call(__MODULE__, :save)
  end

  @doc "Adds or replaces an engine in config and saves."
  def upsert_engine(engine_map) do
    GenServer.call(__MODULE__, {:upsert_engine, engine_map})
  end

  @doc "Adds or replaces a model in config and saves."
  def upsert_model(model_map) do
    GenServer.call(__MODULE__, {:upsert_model, model_map})
  end

  @doc "Removes an engine by alias."
  def delete_engine(engine_alias) do
    GenServer.call(__MODULE__, {:delete_engine, engine_alias})
  end

  @doc "Removes a model by alias."
  def delete_model(model_alias) do
    GenServer.call(__MODULE__, {:delete_model, model_alias})
  end

  # ── GenServer callbacks ───────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    config = load_from_disk() || default_config()
    {:ok, config}
  end

  @impl true
  def handle_call(:get, _from, state), do: {:reply, state, state}

  @impl true
  def handle_call(:reload, _from, _state) do
    config = load_from_disk() || default_config()
    {:reply, :ok, config}
  end

  @impl true
  def handle_call(:save, _from, state) do
    result = write_to_disk(state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:upsert_engine, engine_map}, _from, state) do
    alias_key = engine_map.alias || engine_map["alias"]
    new_state = put_in(state, [:engines, alias_key], engine_map)
    write_to_disk(new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:upsert_model, model_map}, _from, state) do
    model_alias = model_map.alias || model_map["alias"]
    existing = state.models || []
    updated  = case Enum.find_index(existing, &(&1.alias == model_alias)) do
      nil -> existing ++ [model_map]
      idx -> List.replace_at(existing, idx, model_map)
    end
    new_state = %{state | models: updated}
    write_to_disk(new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:delete_engine, engine_alias}, _from, state) do
    new_state = update_in(state, [:engines], &Map.delete(&1, engine_alias))
    write_to_disk(new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:delete_model, model_alias}, _from, state) do
    new_state = update_in(state, [:models], &Enum.reject(&1, fn m -> m.alias == model_alias end))
    write_to_disk(new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:update_affinity, model_alias, task_type, value}, _from, state) do
    models = Enum.map(state.models || [], fn m ->
      if m.alias == model_alias do
        put_in(m, [:routing, :task_affinity, task_type], value)
      else
        m
      end
    end)
    {:reply, :ok, %{state | models: models}}
  end

  # ── Private ───────────────────────────────────────────────────────────────

  defp load_from_disk do
    with {:ok, raw}    <- File.read(@config_path),
         {:ok, parsed} <- Jason.decode(raw, keys: :atoms) do
      parsed
    else
      {:error, :enoent} ->
        Logger.info("[Config.Loader] No config file found at #{@config_path}. Using defaults.")
        nil
      {:error, reason} ->
        Logger.warning("[Config.Loader] Error reading config: #{inspect(reason)}. Using defaults.")
        nil
    end
  end

  defp write_to_disk(config) do
    dir = Path.dirname(@config_path)
    File.mkdir_p!(dir)
    case Jason.encode(config, pretty: true) do
      {:ok, json}    -> File.write(@config_path, json)
      {:error, _} = e -> e
    end
  end

  def default_config do
    %{
      meta: %{version: "1.0", created_at: DateTime.utc_now() |> DateTime.to_iso8601()},
      system: %{
        http_port: 8081,
        log_level: "info",
        telemetry_enabled: true,
        auth_enabled: false,
        allow_anonymous: true
      },
      session_defaults: %{
        latency_tolerance_ms: 5000,
        context_mode: "transparent",
        window_size: 10,
        summary_strategy: "eager",
        summary_trigger_pct: 0.8,
        summarize_with_model: "auto"
      },
      engines: %{},
      models: [],
      routing: %{
        complexity_weights: %{
          token_estimate: 0.3, task_type: 0.25,
          sentence_depth: 0.2, vocabulary_density: 0.15,
          question_count: 0.1
        },
        cold_start_penalty_factor: 1.5,
        max_consecutive_errors_before_exclude: 3,
        fallback_timeout_ms: 15_000
      },
      cluster: %{enabled: false, role: "both"},
      auto_tune: %{enabled: false, check_interval_hours: 24, min_confidence: 0.8, min_decisions: 100}
    }
  end
end
```

Actualizar ElPaso.Config para ser una fachada limpia sin llamadas a Loader.get() en Application:

```elixir
defmodule ElPaso.Config do
  alias ElPaso.Config.Loader

  def http_port do
    System.get_env("ELPASO_PORT")
    |> case do
      nil  -> get_in(Loader.get(), [:system, :http_port]) || 8081
      port -> String.to_integer(port)
    end
  end

  def cluster_enabled?, do: get_in(Loader.get(), [:cluster, :enabled]) == true
  def cluster_discovery, do: get_in(Loader.get(), [:cluster, :discovery]) || "static"
  def node_role,         do: (get_in(Loader.get(), [:cluster, :role]) || "both") |> String.to_atom()
  def node_name,         do: System.get_env("ELPASO_NODE_NAME")
  def auth_enabled?,     do: get_in(Loader.get(), [:system, :auth_enabled]) == true
  def allow_anonymous?,  do: get_in(Loader.get(), [:system, :allow_anonymous]) != false
  def auto_tune_enabled?,   do: get_in(Loader.get(), [:auto_tune, :enabled]) == true
  def auto_tune_min_confidence, do: get_in(Loader.get(), [:auto_tune, :min_confidence]) || 0.8
  def auto_tune_min_decisions,  do: get_in(Loader.get(), [:auto_tune, :min_decisions])  || 100
  def auto_tune_check_interval_hours, do: get_in(Loader.get(), [:auto_tune, :check_interval_hours]) || 24
end
```

✓ Verificación: `mix run -e "IO.inspect(ElPaso.Config.Loader.get())"` devuelve defaults sin excepción.

---

## 1.2 — Reescribir Application.start/2

Problemas actuales:
- Llama a `Config.cluster_enabled?()` que llama a `Loader.get()` → crash
- Llama a `ModelDownloaderRegistry.init()` que no existe
- No tiene ElPaso.Repo ni Finch ni Config.Loader como hijos

```elixir
defmodule ElPaso.Application do
  use Application
  require Logger

  @impl Application
  def start(_type, _args) do
    # Config.Loader debe ser el PRIMER hijo — todo lo demás lo necesita
    children = [
      ElPaso.Config.Loader,
      ElPaso.Repo,
      {Finch, name: ElPasoFinch, pools: %{default: [size: 10]}},
      ElPaso.Security.RateLimiter,
      ElPaso.Engine.Registry,
      ElPaso.Domain.ModelSupervisor,
      ElPaso.Context.PrefixManager,
      ElPaso.Context.Manager,
      ElPaso.Context.SummarizationSupervisor,
      ElPaso.Domain.Router,
      ElPaso.Domain.OutputCache,
      ElPaso.Telemetry.Store,
      ElPaso.Event.Supervisor,
      ElPaso.Domain.AutoTuner,
      {Plug.Cowboy,
       scheme: :http,
       plug: ElPaso.HTTP.Server,
       options: [port: 8081, dispatch: dispatch()]}
    ] ++ cluster_children()

    Logger.info("[ElPaso] Starting on port #{ElPaso.Config.http_port()}")
    Supervisor.start_link(children, strategy: :one_for_one, name: ElPaso.Supervisor)
  end

  defp dispatch do
    [
      {:_, [
        {"/v1/chat/ws", ElPaso.HTTP.WebSocketHandler, []},
        {:_, Plug.Cowboy.Handler, {ElPaso.HTTP.Server, []}}
      ]}
    ]
  end

  defp cluster_children do
    # Config ya está arrancado en este punto — safe
    if ElPaso.Config.cluster_enabled?() do
      base = [ElPaso.Cluster.NodeRegistry]
      if ElPaso.Config.cluster_discovery() == "gossip" do
        [{Cluster.Supervisor, [[gossip: [strategy: Cluster.Strategy.Gossip,
           config: [port: 45_892, multicast_addr: "230.1.1.251"]]]]} | base]
      else
        base
      end
    else
      []
    end
  end
end
```

Añadir RateLimiter como GenServer (actualmente es solo funciones estáticas con ETS):

```elixir
# En ElPaso.Security.RateLimiter — añadir start_link/1 e init/1:
def start_link(_opts) do
  :ets.new(:elpaso_rate_limiter, [:named_table, :public, :set,
    {:write_concurrency, true}, {:read_concurrency, true}])
  {:ok, :no_gen_server_needed}
end

# O convertir a GenServer si se necesita estado:
# use Agent
# def start_link(_), do: Agent.start_link(fn -> init_table() end, name: __MODULE__)
```

✓ Verificación: `mix run --no-halt` arranca sin excepción. Log muestra "[ElPaso] Starting on port 8081".

---

## 1.3 — Eliminar hello/world de el_paso.ex

```elixir
defmodule ElPaso do
  @moduledoc """
  ElPaso — multi-model inference proxy.

  See `ElPaso.Config.Loader` to configure engines and models.
  See `ElPaso.HTTP.Server` for the HTTP API.
  """
end
```

---

## 1.4 — Primer arranque: detector de configuración faltante

Cuando ElPaso arranca y no hay `elpaso.conf` (o tiene `engines: {}` y `models: []`),
debe informar al usuario de forma clara en lugar de simplemente arrancar silenciosamente.

Añadir en `Application.start/2` tras arrancar todos los hijos:

```elixir
# Al final de start/2, tras Supervisor.start_link:
case result do
  {:ok, pid} ->
    warn_if_unconfigured()
    {:ok, pid}
  error ->
    error
end

defp warn_if_unconfigured do
  config = ElPaso.Config.Loader.get()
  engines = config.engines || %{}
  models  = config.models  || []

  if map_size(engines) == 0 and length(models) == 0 do
    IO.puts("""

    ╔══════════════════════════════════════════════════════════════╗
    ║  ElPaso started with no engines or models configured.        ║
    ║                                                              ║
    ║  To add an engine:  mix elpaso engine add                    ║
    ║  To add a model:    mix elpaso model add                     ║
    ║  To use the wizard: mix elpaso init                          ║
    ║                                                              ║
    ║  Config file: ~/.config/elpaso/elpaso.conf                   ║
    ╚══════════════════════════════════════════════════════════════╝
    """)
  end
end
```

---

## 1.5 — Errores controlados: envolver todos los puntos de fallo con rescue/catch limpio

Principio: ElPaso nunca debe mostrar una stacktrace al usuario. Los errores conocidos
se loguean como warning o error y se devuelve un resultado estructurado.

Aplicar a todos los módulos:

**Config.Loader.get/0** (ya corregido en 1.1, nunca lanza).

**Context.Storage** — cada función debe rescatar errores de Ecto:
```elixir
def get_session(session_id) do
  case Repo.get(Session, session_id) do
    nil     -> {:error, :not_found}
    session -> {:ok, session}
  end
rescue
  e in Ecto.QueryError ->
    Logger.error("[Storage] DB error in get_session: #{Exception.message(e)}")
    {:error, :db_error}
  e ->
    Logger.error("[Storage] Unexpected error: #{Exception.message(e)}")
    {:error, :internal}
end
```

**Engine.Dispatcher.infer/3** — rescatar errores de red/timeout:
```elixir
def infer(model_id, built_prompt, params) do
  # ... implementación ...
rescue
  e in Finch.Error ->
    {:error, {:network_error, Exception.message(e)}}
  e ->
    Logger.error("[Dispatcher] infer error for #{model_id}: #{Exception.message(e)}")
    {:error, {:unexpected, Exception.message(e)}}
end
```

**HTTP.Server** — el endpoint principal debe devolver JSON de error, nunca 500 sin cuerpo:
```elixir
# Ya incluido en la implementación de POST /v1/chat/completions de la Sección 5
```

**ModelWorker.launch_engine_process** — ya tiene rescue, asegurarse que es catch-all.

**AutoTuner.do_auto_tune/1** — envolver en try/rescue para que un fallo no detenga el GenServer:
```elixir
defp do_auto_tune(state) do
  try do
    # ... implementación actual ...
  rescue
    e ->
      Logger.error("[AutoTuner] Auto-tune failed: #{Exception.message(e)}")
      schedule_next_run()
      {:noreply, state}
  end
end
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 2 — SISTEMA DE CONFIGURACIÓN: MOTORES Y MODELOS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 2.1 — Diseño del schema de elpaso.conf

El archivo `~/.config/elpaso/elpaso.conf` (JSON) tiene esta estructura:

```json
{
  "meta": {"version": "1.0"},
  "system": {
    "http_port": 8081,
    "log_level": "info",
    "auth_enabled": false,
    "allow_anonymous": true
  },
  "engines": {
    "llama-fast": {
      "alias": "llama-fast",
      "type": "local_process",
      "binary": "/usr/bin/llama-server",
      "base_args": {
        "--host": "0.0.0.0",
        "--port": "8081",
        "--threads": "8",
        "--ctx-size": "4096",
        "--batch-size": "512"
      },
      "accepts_model_types": ["gguf"],
      "openai_compatible": true,
      "anthropic_compatible": false,
      "api_key": "sk-local",
      "health_path": "/health"
    },
    "vllm-local": {
      "alias": "vllm-local",
      "type": "local_process",
      "binary": "/usr/bin/vllm",
      "base_args": {"--host": "0.0.0.0", "--port": "8082"},
      "accepts_model_types": ["safetensors", "awq", "gptq"],
      "openai_compatible": true,
      "anthropic_compatible": false,
      "api_key": "token-abc123"
    },
    "ollama": {
      "alias": "ollama",
      "type": "managed_service",
      "base_url": "http://localhost:11434/v1",
      "accepts_model_types": ["gguf", "safetensors"],
      "openai_compatible": true,
      "api_key": ""
    },
    "openai-remote": {
      "alias": "openai-remote",
      "type": "remote_api",
      "base_url": "https://api.openai.com/v1",
      "openai_compatible": true,
      "api_key": "sk-..."
    }
  },
  "models": [
    {
      "alias": "fast",
      "name": "Llama-3.2-3B-Instruct",
      "path": "~/models/Llama-3.2-3B-Instruct-Q4_K_M.gguf",
      "engine": "llama-fast",
      "parameters_b": 3,
      "quantization": "Q4_K_M",
      "type": ["chat"],
      "max_tokens_context": 8192,
      "max_tokens_output": 4096,
      "supports_tools": false,
      "supports_images": false,
      "supports_parallel_tool_calls": false,
      "supports_prompt_cache_key": true,
      "supports_chat_completions": true,
      "engine_args": {
        "--n-gpu-layers": "35",
        "--flash-attn": true,
        "--port": "8081"
      },
      "context_spec": {
        "chat_template": "llama3",
        "supports_system_prompt": true,
        "max_context_tokens": 8192,
        "reserved_output_tokens": 1024
      },
      "routing": {
        "task_affinity": {
          "general": 0.9,
          "code": 0.5,
          "reasoning": 0.4
        },
        "complexity_ceiling": 0.6,
        "cold_start_estimate_ms": 5000
      },
      "lifecycle": {
        "autostart": true,
        "max_idle_minutes": 30
      }
    }
  ],
  "routing": {
    "complexity_weights": {
      "token_estimate": 0.3,
      "task_type": 0.25,
      "sentence_depth": 0.2,
      "vocabulary_density": 0.15,
      "question_count": 0.1
    },
    "fallback_timeout_ms": 15000,
    "max_consecutive_errors_before_exclude": 3
  }
}
```

---

## 2.2 — Config.Schema: validación del archivo

Crear `lib/el_paso/config/schema.ex`:

```elixir
defmodule ElPaso.Config.Schema do
  @moduledoc "Validates the structure and values of elpaso.conf."

  @valid_engine_types ~w(local_process managed_service remote_api airllm_wrapper)
  @valid_model_types  ~w(chat code reasoning vision embedding thinker multimodal)

  @doc "Validates a config map. Returns {:ok, config} or {:error, [errors]}."
  def validate(config) when is_map(config) do
    errors =
      []
      |> validate_engines(config)
      |> validate_models(config)

    case errors do
      []     -> {:ok, config}
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  defp validate_engines(errors, config) do
    Enum.reduce(config.engines || %{}, errors, fn {alias_key, engine}, acc ->
      alias_str = to_string(alias_key)
      acc
      |> check(engine[:type] in @valid_engine_types,
           "engines.#{alias_str}: invalid type '#{engine[:type]}'. " <>
           "Valid: #{Enum.join(@valid_engine_types, ", ")}")
      |> check(engine[:binary] || engine[:base_url],
           "engines.#{alias_str}: requires either :binary (local) or :base_url (remote)")
      |> check(duplicate_port_check(config.engines, alias_str, engine),
           "engines.#{alias_str}: port already used by another engine")
    end)
  end

  defp validate_models(errors, config) do
    aliases = Enum.map(config.models || [], & &1[:alias])
    dup_aliases = aliases -- Enum.uniq(aliases)

    errors
    |> check(dup_aliases == [], "models: duplicate aliases: #{Enum.join(dup_aliases, ", ")}")
    |> then(fn acc ->
      Enum.reduce(config.models || [], acc, fn model, a ->
        engine_alias = model[:engine]
        a
        |> check(model[:alias], "models[?]: alias is required")
        |> check(model[:engine], "models[#{model[:alias]}]: engine is required")
        |> check(model[:path] || model[:name],
             "models[#{model[:alias]}]: path or name is required")
        |> check(engine_alias == nil or Map.has_key?(config.engines || %{}, engine_alias),
             "models[#{model[:alias]}]: engine '#{engine_alias}' not registered")
        |> validate_model_types(model)
      end)
    end)
  end

  defp validate_model_types(errors, model) do
    types = List.wrap(model[:type] || [])
    invalid = Enum.reject(types, &(&1 in @valid_model_types))
    check(errors, invalid == [],
      "models[#{model[:alias]}]: invalid types: #{Enum.join(invalid, ", ")}")
  end

  defp duplicate_port_check(engines, current_alias, engine) do
    current_port = get_in(engine, [:base_args, "--port"]) ||
                   get_in(engine, [:base_args, :"--port"])
    if current_port do
      Enum.all?(Map.keys(engines || %{}), fn a ->
        to_string(a) == current_alias or
          (get_in(engines[a], [:base_args, "--port"]) != current_port and
           get_in(engines[a], [:base_args, :"--port"]) != current_port)
      end)
    else
      true
    end
  end

  defp check(errors, true, _msg),  do: errors
  defp check(errors, false, msg),  do: [msg | errors]
  defp check(errors, nil, msg),    do: [msg | errors]
end
```

---

## 2.3 — Config.Merger: fusión de engine base_args + model engine_args

Crear `lib/el_paso/config/merger.ex`:

```elixir
defmodule ElPaso.Config.Merger do
  @moduledoc "Merges engine base_args with model engine_args into a CLI argument list."

  @doc """
  Merges base_args (engine-level) with engine_args (model-level).
  Model args override engine base_args. A nil value removes the key.
  Returns a flat list of strings suitable for System.cmd/3.
  """
  @spec merge(map(), map()) :: [String.t()]
  def merge(base_args, model_args)
      when is_map(base_args) and is_map(model_args) do
    base_args
    |> Map.merge(stringify_keys(model_args))
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.flat_map(fn
      {k, true}  -> [to_string(k)]
      {k, false} -> []
      {k, v}     -> [to_string(k), to_string(v)]
    end)
  end

  def merge(nil, model_args) when is_map(model_args), do: merge(%{}, model_args)
  def merge(base_args, nil) when is_map(base_args),   do: merge(base_args, %{})
  def merge(_, _), do: []

  defp stringify_keys(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end
```

---

## 2.4 — Config.EnvironmentDetector: auto-detección de hardware

Crear `lib/el_paso/config/environment_detector.ex`:

```elixir
defmodule ElPaso.Config.EnvironmentDetector do
  @moduledoc "Detects available hardware: GPUs, RAM, CPU threads, available binaries."

  def detect do
    %{
      gpus: detect_gpus(),
      ram_mb: detect_ram_mb(),
      cpu_threads: detect_cpu_threads(),
      available_engines: detect_available_engines()
    }
  end

  def detect_gpus do
    case System.cmd("nvidia-smi",
           ["--query-gpu=name,memory.total", "--format=csv,noheader,nounits"],
           stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.map(fn line ->
          case String.split(line, ", ") do
            [name, vram] -> %{name: String.trim(name), vram_mb: parse_int(vram)}
            _            -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
      _ -> []
    end
  rescue
    _ -> []
  end

  def detect_ram_mb do
    case File.read("/proc/meminfo") do
      {:ok, content} ->
        case Regex.run(~r/MemTotal:\s+(\d+)\s+kB/, content) do
          [_, kb] -> div(String.to_integer(kb), 1024)
          _       -> 0
        end
      _ -> 0
    end
  end

  def detect_cpu_threads do
    case System.cmd("nproc", [], stderr_to_stdout: true) do
      {n, 0} -> n |> String.trim() |> String.to_integer()
      _      -> System.schedulers_online()
    end
  rescue
    _ -> System.schedulers_online()
  end

  def detect_available_engines do
    %{
      llama_server: find_binary("llama-server"),
      vllm: find_binary("vllm"),
      ollama: detect_ollama(),
      airllm: find_python_package("airllm")
    }
  end

  def find_binary(name) do
    case System.find_executable(name) do
      nil  -> :not_found
      path -> {:ok, path}
    end
  end

  def next_available_port(from \\ 8082) do
    Enum.find(from..9000, fn port ->
      case :gen_tcp.listen(port, [:inet]) do
        {:ok, sock} -> :gen_tcp.close(sock); true
        _           -> false
      end
    end) || from
  end

  defp detect_ollama do
    case Finch.build(:get, "http://localhost:11434/api/tags")
         |> Finch.request(ElPasoFinch, receive_timeout: 2_000) do
      {:ok, %{status: 200}} -> {:ok, "http://localhost:11434"}
      _                     -> :not_found
    end
  rescue
    _ -> :not_found
  end

  defp find_python_package(pkg) do
    case System.cmd("python3", ["-c", "import #{pkg}; print('ok')"],
                    stderr_to_stdout: true) do
      {"ok\n", 0} -> :available
      _           -> :not_found
    end
  rescue
    _ -> :not_found
  end

  defp parse_int(s) do
    case Integer.parse(String.trim(s)) do
      {n, _} -> n
      :error -> 0
    end
  end
end
```

---

## 2.5 — AirLLM Wrapper: motor sin endpoint HTTP

AirLLM no expone API HTTP: se usa vía script Python directamente.
ElPaso lo gestiona como un proceso externo con un puerto TCP mini.

Crear `lib/el_paso/engine/airllm_wrapper.ex`:

```elixir
defmodule ElPaso.Engine.AirLLMWrapper do
  @moduledoc """
  Engine adapter for AirLLM (extreme quantization, CPU/low-VRAM inference).

  AirLLM has no HTTP endpoint. This module launches a thin Python bridge
  that exposes an OpenAI-compatible endpoint on a local port, allowing
  ElPaso to treat it like any other engine.

  The bridge script (`priv/airllm_bridge.py`) is included in the release.
  """
  @behaviour ElPaso.Engine

  alias ElPaso.Engine.LlamaServer

  @bridge_script Application.app_dir(:elpaso, "priv/airllm_bridge.py")

  @impl true
  def name, do: :airllm_wrapper

  @impl true
  def type, do: :local_process

  @impl true
  def infer(prompt, params, config) do
    # Once the bridge is running, it's OpenAI-compatible
    LlamaServer.infer(prompt, params, ensure_bridge_config(config))
  end

  @impl true
  def stream(prompt, params, config, cb) do
    LlamaServer.stream(prompt, params, ensure_bridge_config(config), cb)
  end

  @impl true
  def prepare_prefix(prefix, _config), do: prefix

  @impl true
  def health_check(config) do
    LlamaServer.health_check(ensure_bridge_config(config))
  end

  @impl true
  def format_messages(messages, ctx), do: messages

  @doc "Launches the Python bridge for a given model path and port."
  def launch_bridge(model_path, port, opts \\ []) do
    device    = Keyword.get(opts, :device, "cpu")
    script    = @bridge_script
    py_bin    = System.find_executable("python3") || "python3"

    Task.start(fn ->
      System.cmd(py_bin, [script, model_path, "--port", to_string(port), "--device", device],
        into: IO.stream(:stdio, :line))
    end)

    # Wait for bridge to become available (max 60s)
    wait_for_bridge("http://localhost:#{port}/health", 60_000)
  end

  defp wait_for_bridge(_url, timeout) when timeout <= 0, do: {:error, :timeout}
  defp wait_for_bridge(url, timeout) do
    case Finch.build(:get, url) |> Finch.request(ElPasoFinch, receive_timeout: 2_000) do
      {:ok, %{status: 200}} -> :ok
      _ ->
        Process.sleep(2_000)
        wait_for_bridge(url, timeout - 2_000)
    end
  end

  defp ensure_bridge_config(config) do
    port = config[:port] || 8090
    Map.put(config, :base_url, "http://localhost:#{port}/v1")
  end
end
```

Crear `priv/airllm_bridge.py`:

```python
#!/usr/bin/env python3
"""
Thin OpenAI-compatible HTTP bridge for AirLLM.
Usage: python3 airllm_bridge.py <model_path> [--port 8090] [--device cpu]
"""
import argparse
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

try:
    from airllm import AutoModel
except ImportError:
    print("ERROR: airllm not installed. Run: pip install airllm", file=sys.stderr)
    sys.exit(1)

model = None

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args): pass  # suppress default logs

    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body   = json.loads(self.rfile.read(length))
        messages = body.get("messages", [])
        max_new_tokens = body.get("max_tokens", 256)

        prompt = "\n".join(f"[{m['role']}]: {m['content']}" for m in messages)
        prompt += "\n[assistant]:"

        try:
            output = model.generate(
                prompt,
                max_new_tokens=max_new_tokens,
                use_cache=False
            )
            content = output[0] if isinstance(output, list) else str(output)
            resp = {
                "choices": [{"message": {"role": "assistant", "content": content},
                             "finish_reason": "stop", "index": 0}],
                "usage": {"prompt_tokens": len(prompt.split()),
                          "completion_tokens": len(content.split()),
                          "total_tokens": 0}
            }
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(resp).encode())
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    def handle_error(self, request, client_address):
        pass

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("model_path")
    parser.add_argument("--port", type=int, default=8090)
    parser.add_argument("--device", default="cpu")
    args = parser.parse_args()

    print(f"Loading model {args.model_path} on {args.device}...")
    model = AutoModel.from_pretrained(args.model_path, device=args.device)
    print(f"Bridge ready on port {args.port}")
    HTTPServer(("0.0.0.0", args.port), Handler).serve_forever()
```

---

## 2.6 — Nota sobre proveedores remotos futuros

ElPaso está diseñado para motores locales. Los proveedores remotos (OpenAI, Anthropic,
Bedrock, Mistral, etc.) se añadirán en V2.0+ con un mecanismo de plugin.

Para planificarlo correctamente, el engine config ya incluye `type: "remote_api"` y
`api_key`. El `Engine.Dispatcher` ya resuelve `ElPaso.Engine.OpenAI` para engines
de tipo remoto. Lo único que falta es crear los adapters correspondientes en el
futuro. No implementar ahora: documentar en README la extensión planificada.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 3 — SCHEMAS Y MIGRACIONES ECTO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 3.1 — Corregir los 4 schemas

Los schemas actuales tienen tipos incorrectos (`:string` para `session_id`
en lugar de `:binary_id`, `timestamps()` duplicado con campos manuales, etc.)

### Session — reemplazar completo:

```elixir
defmodule ElPaso.Context.Schemas.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sessions" do
    field :context_mode, Ecto.Enum, values: [:transparent, :declarative], default: :transparent
    field :user_id, :string
    field :metadata, :map, default: %{}
    timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: :last_active_at)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:context_mode, :user_id, :metadata])
    |> validate_inclusion(:context_mode, [:transparent, :declarative])
  end
end
```

### Message — reemplazar completo:

```elixir
defmodule ElPaso.Context.Schemas.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @foreign_key_type :binary_id

  schema "messages" do
    field :session_id, :binary_id
    field :sequence_number, :integer
    field :role, :string
    field :content, :string
    field :token_estimate, :integer, default: 0
    field :model_id, :string
    field :archived_at, :utc_datetime_usec
    field :embedding, Pgvector.Ecto.Vector
    timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
  end

  def changeset(msg, attrs) do
    msg
    |> cast(attrs, [:session_id, :sequence_number, :role, :content,
                    :token_estimate, :model_id, :embedding])
    |> validate_required([:session_id, :role, :content])
    |> validate_inclusion(:role, ["user", "assistant", "system"])
  end
end
```

### ConversationSummary — reemplazar:

```elixir
defmodule ElPaso.Context.Schemas.ConversationSummary do
  use Ecto.Schema
  import Ecto.Changeset

  @foreign_key_type :binary_id

  schema "conversation_summaries" do
    field :session_id, :binary_id
    field :content, :string
    field :covers_until_message_id, :integer
    field :token_estimate, :integer, default: 0
    field :generated_by_model, :string
    field :generated_at, :utc_datetime_usec
    field :archived_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
  end

  def changeset(s, attrs) do
    s
    |> cast(attrs, [:session_id, :content, :covers_until_message_id,
                    :token_estimate, :generated_by_model, :generated_at])
    |> validate_required([:session_id, :content, :generated_by_model])
  end
end
```

### RoutingDecision — reemplazar (el actual es minimalista con 3 campos):

```elixir
defmodule ElPaso.Context.Schemas.RoutingDecision do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:request_id, :string, autogenerate: false}
  @foreign_key_type :binary_id

  schema "routing_decisions" do
    field :session_id, :binary_id
    field :selected_model, :string
    field :runner_up, :string
    field :task_type, :string
    field :complexity_score, :float
    field :token_estimate, :integer
    field :feature_vector, :map, default: %{}
    field :scores, :map, default: %{}
    field :reason, :string
    field :outcome, :string
    field :latency_ms, :integer
    field :decision_latency_us, :integer
    field :decided_at, :utc_datetime_usec
  end

  def changeset(rd, attrs) do
    rd
    |> cast(attrs, [:request_id, :session_id, :selected_model, :runner_up,
                    :task_type, :complexity_score, :token_estimate, :feature_vector,
                    :scores, :reason, :outcome, :latency_ms,
                    :decision_latency_us, :decided_at])
    |> validate_required([:request_id, :selected_model, :task_type])
  end
end
```

## 3.2 — Crear las 4 migraciones

Ver sección 1.4 del prompt anterior. Las migraciones deben ir en
`priv/repo/migrations/` con timestamps ordenados.

Añadir migration de config persistence (V1.0 engines y modelos en DB como caché):

```elixir
# priv/repo/migrations/20250101000005_create_auto_tune_runs.exs
defmodule ElPaso.Repo.Migrations.CreateAutoTuneRuns do
  use Ecto.Migration
  def change do
    create table(:auto_tune_runs) do
      add :applied_changes, :integer, default: 0
      add :changes_json, :text
      add :ran_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
    end
  end
end
```

✓ Verificación: `mix ecto.migrate` aplica 5 migraciones sin errores.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 4 — CLI: COMANDOS DE GESTIÓN DE MOTORES Y MODELOS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 4.1 — Mix tasks: interfaz principal de gestión

Crear los siguientes Mix tasks bajo `lib/mix/tasks/`:

### `mix elpaso.init` — wizard interactivo de primer arranque

```elixir
defmodule Mix.Tasks.Elpaso.Init do
  use Mix.Task

  @shortdoc "Interactive wizard to configure ElPaso for the first time"
  @moduledoc """
  Interactive setup wizard for ElPaso.

  Detects available hardware and engine binaries, then guides the user
  through registering at least one engine and one model.

      $ mix elpaso.init
  """

  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("\n=== ElPaso Setup Wizard ===\n")
    hw = ElPaso.Config.EnvironmentDetector.detect()

    IO.puts("Detected hardware:")
    IO.puts("  RAM: #{hw.ram_mb} MB")
    IO.puts("  CPU threads: #{hw.cpu_threads}")
    Enum.each(hw.gpus, fn g ->
      IO.puts("  GPU: #{g.name} (#{g.vram_mb} MB VRAM)")
    end)

    IO.puts("\nAvailable engine binaries:")
    Enum.each(hw.available_engines, fn {engine, status} ->
      status_str = case status do
        {:ok, path} -> "✓ #{path}"
        :available  -> "✓ (python package)"
        :not_found  -> "✗ not found"
      end
      IO.puts("  #{engine}: #{status_str}")
    end)

    IO.puts("\nLet's register your first engine.")
    IO.puts("(You can add more later with: mix elpaso.engine.add)\n")

    Mix.Task.run("elpaso.engine.add")
    Mix.Task.run("elpaso.model.add")

    IO.puts("\n✓ Setup complete! Start ElPaso with: mix run --no-halt")
    IO.puts("  Config saved at: ~/.config/elpaso/elpaso.conf\n")
  end
end
```

### `mix elpaso.engine.add` — registrar un motor

```elixir
defmodule Mix.Tasks.Elpaso.Engine.Add do
  use Mix.Task

  @shortdoc "Register a new inference engine"
  @moduledoc """
  Registers a new inference engine in ElPaso configuration.

  Supported engine types:
    - local_process   Local binary (llama-server, vllm)
    - managed_service Running service (Ollama)
    - remote_api      Remote API (OpenAI, Anthropic, etc.)
    - airllm_wrapper  AirLLM (extreme quantization, no endpoint)

  Examples:

      # Interactive:
      $ mix elpaso.engine.add

      # Non-interactive (all flags):
      $ mix elpaso.engine.add \\
          --alias llama-fast \\
          --type local_process \\
          --binary /usr/bin/llama-server \\
          --port 8081 \\
          --threads 8 \\
          --ctx-size 4096 \\
          --gpu-layers 35
  """

  def run(args) do
    Mix.Task.run("app.start")
    {opts, _, _} = OptionParser.parse(args,
      switches: [alias: :string, type: :string, binary: :string,
                 base_url: :string, port: :integer, api_key: :string,
                 threads: :integer, ctx_size: :integer, gpu_layers: :integer,
                 openai_compatible: :boolean, anthropic_compatible: :boolean])

    engine = if Keyword.has_key?(opts, :alias) do
      build_engine_from_opts(opts)
    else
      interactive_engine_wizard()
    end

    with {:ok, _}         <- ElPaso.Config.Schema.validate_engine(engine),
         :ok              <- check_no_duplicate_port(engine),
         :ok              <- ElPaso.Config.Loader.upsert_engine(engine) do
      IO.puts("\n✓ Engine '#{engine.alias}' registered successfully.")
      IO.puts("  Use it in a model with: engine: \"#{engine.alias}\"")
    else
      {:error, reason} ->
        IO.puts("\n✗ Failed to register engine: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp interactive_engine_wizard do
    alias_name = prompt("Engine alias (e.g. llama-fast, vllm-local, ollama): ")
    type = prompt_choice("Engine type",
      ["local_process", "managed_service", "remote_api", "airllm_wrapper"])

    base_map = %{alias: alias_name, type: type, openai_compatible: true,
                 anthropic_compatible: false}

    case type do
      "local_process" ->
        binary = prompt("Binary path (e.g. /usr/bin/llama-server): ")
        port   = prompt("Listening port [8081]: ", "8081") |> String.to_integer()
        threads = prompt("CPU threads [8]: ", "8") |> String.to_integer()
        ctx    = prompt("Context size tokens [4096]: ", "4096") |> String.to_integer()
        gpu    = prompt("GPU layers (-1 = all, 0 = CPU-only) [35]: ", "35") |> String.to_integer()
        Map.merge(base_map, %{
          binary: binary,
          base_args: %{"--port" => port, "--threads" => threads,
                       "--ctx-size" => ctx, "--n-gpu-layers" => gpu,
                       "--host" => "0.0.0.0"},
          accepts_model_types: ["gguf"],
          api_key: "sk-local",
          health_path: "/health"
        })

      "managed_service" ->
        url = prompt("Service URL [http://localhost:11434/v1]: ",
                     "http://localhost:11434/v1")
        Map.merge(base_map, %{base_url: url, api_key: "", accepts_model_types: ["gguf"]})

      "remote_api" ->
        url    = prompt("API base URL: ")
        key    = prompt("API key: ")
        Map.merge(base_map, %{base_url: url, api_key: key})

      "airllm_wrapper" ->
        port = prompt("Bridge port [8090]: ", "8090") |> String.to_integer()
        dev  = prompt_choice("Device", ["cpu", "cuda:0", "mps"])
        Map.merge(base_map, %{bridge_port: port, device: dev,
                              accepts_model_types: ["safetensors", "gguf"]})
    end
  end

  defp build_engine_from_opts(opts) do
    port = Keyword.get(opts, :port, 8081)
    %{
      alias: Keyword.fetch!(opts, :alias),
      type: Keyword.get(opts, :type, "local_process"),
      binary: Keyword.get(opts, :binary),
      base_url: Keyword.get(opts, :base_url),
      api_key: Keyword.get(opts, :api_key, "sk-local"),
      openai_compatible: Keyword.get(opts, :openai_compatible, true),
      anthropic_compatible: Keyword.get(opts, :anthropic_compatible, false),
      base_args: %{
        "--port" => port,
        "--threads" => Keyword.get(opts, :threads, 8),
        "--ctx-size" => Keyword.get(opts, :ctx_size, 4096),
        "--n-gpu-layers" => Keyword.get(opts, :gpu_layers, 35),
        "--host" => "0.0.0.0"
      }
    }
  end

  defp check_no_duplicate_port(engine) do
    current_port = get_in(engine, [:base_args, "--port"])
    if current_port do
      existing = ElPaso.Config.Loader.list_engines()
      conflict = Enum.find(existing, fn e ->
        e.alias != engine.alias and
          get_in(e, [:base_args, "--port"]) == current_port
      end)
      if conflict do
        {:error, "Port #{current_port} already used by engine '#{conflict.alias}'"}
      else
        :ok
      end
    else
      :ok
    end
  end

  defp prompt(msg, default \\ nil) do
    IO.write(msg)
    case IO.gets("") |> String.trim() do
      "" when default != nil -> default
      ""                     -> prompt(msg, default)
      input                  -> input
    end
  end

  defp prompt_choice(label, choices) do
    IO.puts("#{label}:")
    choices
    |> Enum.with_index(1)
    |> Enum.each(fn {c, i} -> IO.puts("  #{i}. #{c}") end)
    IO.write("Choice [1]: ")
    case IO.gets("") |> String.trim() do
      ""  -> List.first(choices)
      n   ->
        case Integer.parse(n) do
          {idx, ""} when idx >= 1 and idx <= length(choices) -> Enum.at(choices, idx - 1)
          _                                                   -> List.first(choices)
        end
    end
  end
end
```

### `mix elpaso.engine.list`, `mix elpaso.engine.remove`, `mix elpaso.engine.test`

```elixir
defmodule Mix.Tasks.Elpaso.Engine.List do
  use Mix.Task
  @shortdoc "List registered engines"

  def run(_) do
    Mix.Task.run("app.start")
    engines = ElPaso.Config.Loader.list_engines()
    if engines == [] do
      IO.puts("No engines registered. Run: mix elpaso.engine.add")
    else
      IO.puts("\nRegistered engines:\n")
      Enum.each(engines, fn e ->
        port = get_in(e, [:base_args, "--port"]) || get_in(e, [:base_url]) || "N/A"
        IO.puts("  #{e.alias}")
        IO.puts("    type:   #{e.type}")
        IO.puts("    port:   #{port}")
        IO.puts("    models: #{count_models_for_engine(e.alias)}")
        IO.puts("")
      end)
    end
  end

  defp count_models_for_engine(engine_alias) do
    ElPaso.Config.Loader.list_models()
    |> Enum.count(&(&1[:engine] == engine_alias))
  end
end

defmodule Mix.Tasks.Elpaso.Engine.Remove do
  use Mix.Task
  @shortdoc "Remove a registered engine"
  def run([alias_name | _]) do
    Mix.Task.run("app.start")
    models_using = ElPaso.Config.Loader.list_models()
                   |> Enum.filter(&(&1[:engine] == alias_name))
    if models_using != [] do
      IO.puts("Cannot remove: #{length(models_using)} model(s) use this engine.")
      IO.puts("Remove them first with: mix elpaso.model.remove <alias>")
      System.halt(1)
    end
    :ok = ElPaso.Config.Loader.delete_engine(alias_name)
    IO.puts("✓ Engine '#{alias_name}' removed.")
  end
  def run(_), do: IO.puts("Usage: mix elpaso.engine.remove <alias>")
end

defmodule Mix.Tasks.Elpaso.Engine.Test do
  use Mix.Task
  @shortdoc "Test connectivity to a registered engine"
  def run([alias_name | _]) do
    Mix.Task.run("app.start")
    case ElPaso.Config.Loader.get_engine(alias_name) do
      {:ok, engine_config} ->
        IO.write("Testing engine '#{alias_name}'... ")
        engine_mod = resolve_engine_module(engine_config[:type])
        case engine_mod.health_check(engine_config) do
          :ok          -> IO.puts("✓ OK")
          {:error, r}  -> IO.puts("✗ Failed: #{inspect(r)}")
        end
      {:error, :engine_not_found} ->
        IO.puts("Engine '#{alias_name}' not found.")
    end
  end
  def run(_), do: IO.puts("Usage: mix elpaso.engine.test <alias>")

  defp resolve_engine_module("local_process"),   do: ElPaso.Engine.LlamaServer
  defp resolve_engine_module("managed_service"), do: ElPaso.Engine.Ollama
  defp resolve_engine_module("remote_api"),      do: ElPaso.Engine.OpenAI
  defp resolve_engine_module("airllm_wrapper"),  do: ElPaso.Engine.AirLLMWrapper
  defp resolve_engine_module(_),                 do: ElPaso.Engine.LlamaServer
end
```

### `mix elpaso.model.add` — registrar un modelo

```elixir
defmodule Mix.Tasks.Elpaso.Model.Add do
  use Mix.Task
  @shortdoc "Register a new model"
  @moduledoc """
  Registers a new model in ElPaso configuration.

  Examples:

      # Interactive:
      $ mix elpaso.model.add

      # Non-interactive:
      $ mix elpaso.model.add \\
          --alias fast \\
          --name "Llama-3.2-3B-Instruct" \\
          --path ~/models/llama3.2-3b-q4.gguf \\
          --engine llama-fast \\
          --params 3 \\
          --quantization Q4_K_M \\
          --type chat \\
          --max-context 8192 \\
          --max-output 4096 \\
          --template llama3
  """

  def run(args) do
    Mix.Task.run("app.start")
    {opts, _, _} = OptionParser.parse(args,
      switches: [alias: :string, name: :string, path: :string, engine: :string,
                 params: :string, quantization: :string, type: :string,
                 max_context: :integer, max_output: :integer, template: :string,
                 supports_tools: :boolean, supports_images: :boolean,
                 autostart: :boolean, gpu_layers: :integer])

    model = if Keyword.has_key?(opts, :alias) do
      build_model_from_opts(opts)
    else
      interactive_model_wizard()
    end

    with {:ok, _}   <- ElPaso.Config.Schema.validate_model(model, ElPaso.Config.Loader.get()),
         :ok        <- ElPaso.Config.Loader.upsert_model(model) do
      IO.puts("\n✓ Model '#{model.alias}' registered.")
      IO.puts("  Test with: curl -X POST http://localhost:8081/v1/chat/completions \\")
      IO.puts("    -d '{\"model\":\"#{model.alias}\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}'")
    else
      {:error, reason} ->
        IO.puts("\n✗ Failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp interactive_model_wizard do
    engines = ElPaso.Config.Loader.list_engines()
    if engines == [] do
      IO.puts("No engines registered. Register one first: mix elpaso.engine.add")
      System.halt(1)
    end

    alias_name   = prompt("Model alias (e.g. fast, coder, reasoner): ")
    model_name   = prompt("Model name (e.g. Llama-3.2-3B-Instruct): ")
    path         = prompt("Model file path (e.g. ~/models/model.gguf): ")

    IO.puts("\nAvailable engines:")
    Enum.with_index(engines, 1) |> Enum.each(fn {e, i} -> IO.puts("  #{i}. #{e.alias}") end)
    engine_choice = prompt("Engine alias: ")

    params       = prompt("Parameters (e.g. 3, 7, 30, 70) [unknown]: ", "unknown")
    quant        = prompt("Quantization (e.g. Q4_K_M, Q8_0, F16) [Q4_K_M]: ", "Q4_K_M")
    type         = prompt_multiselect("Model type(s)",
                     ["chat", "code", "reasoning", "vision", "embedding", "thinker"])
    max_ctx      = prompt("Max context tokens [8192]: ", "8192") |> String.to_integer()
    max_out      = prompt("Max output tokens [4096]: ", "4096") |> String.to_integer()
    template     = prompt_choice("Chat template",
                     ["llama3", "chatml", "gemma", "mistral", "openai"])
    tools        = prompt("Supports tools? [n]: ", "n") |> String.downcase() == "y"
    images       = prompt("Supports images? [n]: ", "n") |> String.downcase() == "y"
    autostart    = prompt("Auto-start on boot? [y]: ", "y") |> String.downcase() == "y"

    %{
      alias: alias_name,
      name: model_name,
      path: Path.expand(path),
      engine: engine_choice,
      parameters_b: params,
      quantization: quant,
      type: type,
      max_tokens_context: max_ctx,
      max_tokens_output: max_out,
      supports_tools: tools,
      supports_images: images,
      supports_parallel_tool_calls: false,
      supports_prompt_cache_key: true,
      supports_chat_completions: true,
      context_spec: %{
        chat_template: template,
        supports_system_prompt: true,
        max_context_tokens: max_ctx,
        reserved_output_tokens: min(max_out, 1024)
      },
      routing: %{
        task_affinity: default_affinity_for_type(type),
        complexity_ceiling: 1.0,
        cold_start_estimate_ms: 10_000
      },
      lifecycle: %{autostart: autostart, max_idle_minutes: 30}
    }
  end

  defp build_model_from_opts(opts) do
    type = Keyword.get(opts, :type, "chat")
    max_ctx = Keyword.get(opts, :max_context, 8192)
    max_out = Keyword.get(opts, :max_output, 4096)
    %{
      alias: Keyword.fetch!(opts, :alias),
      name: Keyword.get(opts, :name, ""),
      path: Path.expand(Keyword.get(opts, :path, "")),
      engine: Keyword.fetch!(opts, :engine),
      parameters_b: Keyword.get(opts, :params, "unknown"),
      quantization: Keyword.get(opts, :quantization, ""),
      type: [type],
      max_tokens_context: max_ctx,
      max_tokens_output: max_out,
      supports_tools: Keyword.get(opts, :supports_tools, false),
      supports_images: Keyword.get(opts, :supports_images, false),
      supports_parallel_tool_calls: false,
      supports_prompt_cache_key: true,
      supports_chat_completions: true,
      context_spec: %{
        chat_template: Keyword.get(opts, :template, "chatml"),
        supports_system_prompt: true,
        max_context_tokens: max_ctx,
        reserved_output_tokens: min(max_out, 1024)
      },
      routing: %{
        task_affinity: default_affinity_for_type([type]),
        complexity_ceiling: 1.0,
        cold_start_estimate_ms: 10_000
      },
      lifecycle: %{autostart: Keyword.get(opts, :autostart, true), max_idle_minutes: 30}
    }
  end

  defp default_affinity_for_type(types) do
    Enum.reduce(types, %{}, fn
      "code",      acc -> Map.merge(%{code: 0.9, general: 0.5, reasoning: 0.4}, acc)
      "reasoning", acc -> Map.merge(%{reasoning: 0.9, general: 0.6, code: 0.5}, acc)
      "chat",      acc -> Map.merge(%{general: 0.9, code: 0.4, reasoning: 0.5}, acc)
      _,           acc -> Map.merge(%{general: 0.7}, acc)
    end)
  end

  defp prompt(msg, default \\ nil) do
    IO.write(msg)
    case IO.gets("") |> String.trim() do
      "" when default != nil -> default
      "" -> prompt(msg, default)
      v  -> v
    end
  end

  defp prompt_choice(label, choices) do
    IO.puts("#{label}:")
    choices |> Enum.with_index(1) |> Enum.each(fn {c, i} -> IO.puts("  #{i}. #{c}") end)
    IO.write("Choice [1]: ")
    case IO.gets("") |> String.trim() do
      "" -> List.first(choices)
      n  ->
        case Integer.parse(n) do
          {i, ""} when i >= 1 and i <= length(choices) -> Enum.at(choices, i - 1)
          _ -> List.first(choices)
        end
    end
  end

  defp prompt_multiselect(label, choices) do
    IO.puts("#{label} (comma-separated numbers):")
    choices |> Enum.with_index(1) |> Enum.each(fn {c, i} -> IO.puts("  #{i}. #{c}") end)
    IO.write("Choices [1]: ")
    case IO.gets("") |> String.trim() do
      "" -> [List.first(choices)]
      s  ->
        s
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.flat_map(fn n ->
          case Integer.parse(n) do
            {i, ""} when i >= 1 and i <= length(choices) -> [Enum.at(choices, i - 1)]
            _ -> []
          end
        end)
    end
  end
end
```

### Tasks adicionales (crear, implementación corta):

- `mix elpaso.model.list` — lista modelos con estado (hot/cold/error)
- `mix elpaso.model.remove <alias>` — elimina modelo
- `mix elpaso.model.start <alias>` — arranca el motor del modelo
- `mix elpaso.model.stop <alias>` — para el motor del modelo
- `mix elpaso.config.show` — muestra config actual formateada
- `mix elpaso.config.validate` — valida elpaso.conf con Config.Schema

Actualizar el CLI dispatcher `run/1` para incluir todos los nuevos comandos.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 5 — HTTP: ENDPOINTS FALTANTES E IMPLEMENTACIONES REALES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 5.1 — Añadir GET /health, GET /v1/models, POST /v1/chat/completions

Ver implementación completa en el prompt previo (Sección 6).
Añadir también los handlers privados faltantes.

## 5.2 — Reemplazar run_anthropic_pipeline con llamada real al Dispatcher

```elixir
defp run_anthropic_pipeline(internal_req, conn) do
  user_id    = conn.assigns[:current_user_id] || "anonymous"
  session_id = internal_req[:session_id] || generate_request_id()
  model_id   = internal_req[:model] || "auto"
  messages   = internal_req[:messages] || []

  with {:ok, _, _}              <- ElPaso.Context.Manager.get_or_create_session(session_id, user_id),
       {:ok, chosen_model, _}   <- ElPaso.Domain.Router.route(
                                     generate_request_id(), session_id,
                                     last_user_message(messages), %{}),
       :ok                      <- ElPaso.Domain.ModelManager.ensure_hot(chosen_model, 30_000),
       {:ok, model_config}      <- ElPaso.Config.Loader.get_model(chosen_model),
       {:ok, built_prompt}      <- ElPaso.Context.Builder.build(
                                     session_id,
                                     last_user_message(messages),
                                     build_context_spec(model_config)) do
    ElPaso.Engine.Dispatcher.infer(chosen_model, built_prompt, %{})
  end
end
```

## 5.3 — WebSocket: reemplazar simulación con pipeline real

```elixir
defp process_chat_stream(messages, params, state, task_ref) do
  parent = self()
  model_id = Map.get(params, "model", "auto")

  with {:ok, chosen_model, _}  <- ElPaso.Domain.Router.route(
                                    generate_request_id(), state.session_id,
                                    last_user_message(messages), %{}),
       :ok                     <- ElPaso.Domain.ModelManager.ensure_hot(chosen_model, 30_000),
       {:ok, model_config}     <- ElPaso.Config.Loader.get_model(chosen_model),
       {:ok, built_prompt}     <- ElPaso.Context.Builder.build(
                                    state.session_id,
                                    last_user_message(messages),
                                    build_context_spec(model_config)) do
    ElPaso.Engine.Dispatcher.stream(chosen_model, built_prompt, %{}, fn chunk ->
      send(parent, {:ws_chunk, %{type: "chunk", content: chunk.content,
                                 done: chunk.done, task_ref: inspect(task_ref)}})
    end)
  end

  send(parent, :done)
end
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 6 — MCP, SKILLS Y AGENTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 6.1 — ¿Tiene sentido implementarlos? Decisión estratégica

**MCP (Model Context Protocol)**: Sí. Es el estándar emergente para conectar
LLMs con herramientas. ElPaso es un proxy: implementar MCP como cliente
(llamar a servidores MCP externos) y como servidor (exponer capacidades ElPaso
a clientes que lo soporten, como Claude Desktop, Cursor, etc.) es de alto valor.

**Skills** (funciones locales tipadas que el modelo puede llamar): Sí.
Son la capa más simple de tool use: funciones Elixir registradas que el
Dispatcher puede incluir en el contexto como tool definitions.

**Agents**: Planificar, no implementar ahora. Un Agent en ElPaso sería
un bucle de razonamiento-acción multi-turno. Requiere Skills y MCP funcionando
primero. Documentar la arquitectura prevista.

## 6.2 — Skills: diseño e implementación

Un Skill es un módulo Elixir que implementa el behaviour `ElPaso.Skill`:

```elixir
defmodule ElPaso.Skill do
  @moduledoc "Behaviour for ElPaso skills (typed callable functions for LLMs)."

  @doc "Unique skill identifier (used in tool_name in the OpenAI tools format)."
  @callback name() :: String.t()

  @doc "Human-readable description for the model."
  @callback description() :: String.t()

  @doc "JSON Schema for the input parameters."
  @callback parameters_schema() :: map()

  @doc "Execute the skill with given parameters. Returns {:ok, result} or {:error, reason}."
  @callback call(params :: map()) :: {:ok, term()} | {:error, term()}

  @doc "Optional: called before sending tool results back to the model."
  @callback format_result(result :: term()) :: String.t()
  @optional_callbacks format_result: 1
end
```

Ejemplo de skill integrado (lectura de fichero):

```elixir
defmodule ElPaso.Skills.ReadFile do
  @behaviour ElPaso.Skill

  def name, do: "read_file"
  def description, do: "Read the contents of a local file."
  def parameters_schema do
    %{
      type: "object",
      properties: %{
        path: %{type: "string", description: "Absolute or relative path to the file"}
      },
      required: ["path"]
    }
  end

  def call(%{"path" => path}) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> {:error, "File not found: #{path}"}
      {:error, reason}  -> {:error, "Cannot read file: #{reason}"}
    end
  end
end
```

Registro de skills en config (`elpaso.conf`):

```json
"skills": {
  "read_file": {"module": "ElPaso.Skills.ReadFile", "enabled": true},
  "web_search": {"module": "ElPaso.Skills.WebSearch", "enabled": false}
}
```

`ElPaso.Skills.Registry` — GenServer que mantiene skills activos:

```elixir
defmodule ElPaso.Skills.Registry do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  def list, do: GenServer.call(__MODULE__, :list)
  def call_skill(name, params), do: GenServer.call(__MODULE__, {:call, name, params})

  def init(:ok) do
    skills = ElPaso.Config.Loader.get()
    |> Map.get(:skills, %{})
    |> Enum.filter(fn {_, v} -> v[:enabled] end)
    |> Enum.map(fn {name, cfg} ->
      mod = Module.concat([cfg[:module]])
      {to_string(name), mod}
    end)
    |> Map.new()
    {:ok, skills}
  end

  def handle_call(:list, _, state) do
    tool_defs = Enum.map(state, fn {_, mod} ->
      %{
        type: "function",
        function: %{
          name: mod.name(),
          description: mod.description(),
          parameters: mod.parameters_schema()
        }
      }
    end)
    {:reply, tool_defs, state}
  end

  def handle_call({:call, name, params}, _, state) do
    case Map.get(state, name) do
      nil -> {:reply, {:error, :skill_not_found}, state}
      mod -> {:reply, mod.call(params), state}
    end
  end
end
```

Integración en el Dispatcher: si el modelo soporta tools, incluir skills:

```elixir
# En Engine.Dispatcher.infer/3, añadir si model soporta tools:
tools = if model_config[:supports_tools] do
  ElPaso.Skills.Registry.list()
else
  []
end
# Pasar tools a engine_mod.infer como parte de params
```

Mix task para registrar skills desde CLI:

```
mix elpaso.skill.add --name my_skill --module MyApp.Skills.MySkill
mix elpaso.skill.list
mix elpaso.skill.remove <name>
```

## 6.3 — MCP Client: conectar a servidores MCP externos

```elixir
defmodule ElPaso.MCP.Client do
  @moduledoc """
  MCP (Model Context Protocol) client for ElPaso.

  Connects to external MCP servers and exposes their tools as ElPaso Skills.
  MCP servers communicate over stdio or HTTP/SSE.
  """

  # MCP servers registered in config:
  # "mcp_servers": [
  #   {"name": "filesystem", "command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem", "/home"]},
  #   {"name": "github",     "url": "http://localhost:3000/sse", "type": "sse"}
  # ]

  def list_server_tools(server_name) do
    # Send {"jsonrpc":"2.0","method":"tools/list","id":1} to the server
    # Return list of tool definitions
    {:ok, []}
  end

  def call_tool(server_name, tool_name, params) do
    # Send {"jsonrpc":"2.0","method":"tools/call","params":{"name":tool_name,"arguments":params}}
    {:ok, %{content: []}}
  end
end
```

Mix tasks para MCP:

```
mix elpaso.mcp.add --name filesystem --command npx --args "-y,@modelcontextprotocol/server-filesystem,/home"
mix elpaso.mcp.add --name github --url http://localhost:3000/sse
mix elpaso.mcp.list
mix elpaso.mcp.test <name>
mix elpaso.mcp.remove <name>
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 7 — HELP SYSTEM Y DOCUMENTACIÓN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 7.1 — Principios de documentación

**Regla de visibilidad antes de documentar:**
Antes de añadir `@doc` a cualquier función, marcarla como `defp` si no forma
parte de la API pública del módulo. Solo las funciones `def` deben tener `@doc`.

Revisión obligatoria de visibilidad:
```bash
# Para cada módulo, identificar funciones que deberían ser privadas:
# - Helpers internos usados solo dentro del módulo → defp
# - Callbacks del behaviour no usados externamente → pueden seguir siendo def
#   pero sin @doc o con @doc false
```

**Idioma:** toda documentación (moduledoc, doc, typedoc, spec, doctest) en inglés.

**Completitud mínima:**
- `@moduledoc`: propósito del módulo, cuándo usarlo, ejemplo básico
- `@doc`: qué hace, qué devuelve, cuándo puede fallar, doctest cuando aplique
- `@spec`: todas las funciones públicas deben tener @spec con tipos concretos
- `@typedoc`: todos los tipos públicos (@type, @opaque) deben tener @typedoc

## 7.2 — Plantilla de moduledoc

```elixir
@moduledoc """
One-line description.

Longer description of what this module does, why it exists, and
how it fits in the overall architecture.

## Usage

    iex> ElPaso.Module.function(arg)
    {:ok, result}

## Configuration

Describe any relevant config keys from elpaso.conf.

## Notes

Any caveats, limitations, or important implementation details.
"""
```

## 7.3 — Help del CLI en inglés con formato consistente

Cada Mix task debe tener:

```elixir
@shortdoc "One-line description shown in mix help"
@moduledoc """
Detailed description.

## Synopsis

    mix elpaso.<command> [options]

## Options

  --option-name   DESCRIPTION  (default: VALUE)
  --flag          Description of what this flag does

## Examples

    # Basic usage
    $ mix elpaso.<command> --option value

    # With all options
    $ mix elpaso.<command> --option-a foo --option-b bar

## See also

  mix elpaso.other.command
"""
```

## 7.4 — README.md: crear dos versiones

### README.md (English):

```markdown
# ElPaso

A multi-model local inference proxy. Single endpoint, multiple models.

## What it does

ElPaso sits between your application and your local LLM engines.
You send requests to a single OpenAI-compatible API, and ElPaso routes
them to the best available model based on task complexity and model affinity.

## Quick Start

    # Install dependencies and create database
    mix setup

    # Register an engine (llama-server, Ollama, vllm...)
    mix elpaso.engine.add

    # Register a model
    mix elpaso.model.add

    # Start the server
    mix run --no-halt

    # Test it
    curl -X POST http://localhost:8081/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d '{"model":"auto","messages":[{"role":"user","content":"Hello"}]}'

## Architecture

[brief description of the 4 pillars: Config, Engine, Context, HTTP]

## Configuration

Config lives in `~/.config/elpaso/elpaso.conf`.

[describe engine and model schema]

## Supported Engines

| Engine | Type | Model formats |
|--------|------|---------------|
| llama-server | local process | GGUF |
| vllm | local process | SafeTensors, AWQ, GPTQ |
| Ollama | managed service | GGUF, SafeTensors |
| AirLLM | local (no endpoint) | SafeTensors |
| OpenAI-compatible | remote API | — |

## API

[OpenAI-compatible endpoints table]

## Development

    mix test
    mix docs
```

### README.es.md (Español):

Misma estructura, traducida.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 8 — LIMPIEZA TRANSVERSAL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 8.1 — Módulos que son stubs a completar o eliminar

- `ElPaso.HTTP.InternalClient` — 3 líneas que devuelven `{:ok, "response"}`.
  Implementar con Finch o eliminar si no se usa.

- `ElPaso.HTTP.WebSocketHandler.process_chat_stream` — simula con Sleep.
  Reemplazar con llamada real al Dispatcher (ver Sección 5.3).

- `ElPaso.HTTP` (el módulo raíz) — `def start/2` que devuelve `:ok`.
  Eliminar o convertir en documentación del subsistema.

- `ElPaso.Event.Supervisor` — `children: []`. Añadir hijos reales o documentar
  qué irá aquí en versiones futuras.

- `ElPaso.Domain.ModelManager` — el actual es un Supervisor vacío con funciones
  que devuelven `[]`. Reemplazar completamente con la implementación de la
  Sección 3 del prompt anterior.

## 8.2 — String.to_atom sin control en CLI parse_options

```elixir
# ACTUAL (bug): atom injection desde args de usuario
defp parse_options(args) do
  Enum.reduce(args, %{}, fn arg, acc ->
    case String.split(arg, "=", parts: 2) do
      [key, value] -> Map.put(acc, String.to_atom(key), value)
```

Las keys vienen del usuario vía CLI. Usar `String.to_existing_atom` con
rescue, o mejor: usar `OptionParser` que ya gestiona esto correctamente.

## 8.3 — RouterAnalyzer.split_into_weekly_windows: use DateTime, not Date

```elixir
# ACTUAL: Date.compare sobre DateTime → tipo incorrecto
Date.compare(d.decided_at, List.first(week_range))
# d.decided_at es %DateTime{}, week_range es %Date{} → incompatible
```

Corregir usando `DateTime.compare` o convirtiendo a Date primero:

```elixir
decision_date = DateTime.to_date(d.decided_at)
Date.compare(decision_date, List.first(week_range)) in [:gt, :eq]
```

## 8.4 — Telemetry.Store: completar métricas reales

El Dashboard devuelve `active: 0, tokens_24h: 0, decisions_1h: 0`.
Implementar las consultas reales en `Telemetry.Store`:

```elixir
def active_session_count do
  import Ecto.Query
  ElPaso.Repo.one(
    from s in ElPaso.Context.Schemas.Session,
    where: s.last_active_at > ^DateTime.add(DateTime.utc_now(), -3600),
    select: count()
  ) || 0
rescue _ -> 0
end

def routing_decisions_last_hour do
  import Ecto.Query
  ElPaso.Repo.one(
    from rd in ElPaso.Context.Schemas.RoutingDecision,
    where: rd.decided_at > ^DateTime.add(DateTime.utc_now(), -3600),
    select: count()
  ) || 0
rescue _ -> 0
end
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CRITERIOS DE COMPLETITUD PARA DAR EL PROYECTO POR TERMINADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

```bash
# 1. Compilación limpia
mix compile --warnings-as-errors
# → 0 warnings

# 2. Arranca sin config file
rm -f ~/.config/elpaso/elpaso.conf
mix run --no-halt &
# → arranca, muestra el banner de "no engines configured", NO explota

# 3. Migraciones
mix ecto.migrate
# → 5 migraciones aplicadas

# 4. Health check
curl http://localhost:8081/health
# → {"status":"ok"}

# 5. Modelos vacíos (sin config)
curl http://localhost:8081/v1/models
# → {"object":"list","data":[]}

# 6. Sin modelos: 503 bien formateado
curl -s -X POST http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"hi"}]}'
# → {"error":{"message":"No models available","type":"no_models_available",...}}

# 7. Wizard de primer arranque funciona
mix elpaso.init
# → detecta hardware, guía registro de engine y modelo

# 8. Registro de engine vía CLI
mix elpaso.engine.add --alias llama-fast --type local_process \
  --binary /usr/bin/llama-server --port 8081 --gpu-layers 35
# → ✓ Engine 'llama-fast' registered successfully.

# 9. Registro de modelo vía CLI
mix elpaso.model.add --alias fast --engine llama-fast \
  --path ~/models/fast.gguf --type chat --template llama3
# → ✓ Model 'fast' registered.

# 10. Con llama-server arrancado: request real funciona
curl -s -X POST http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"Say hello"}]}'
# → respuesta real del modelo con content no vacío y session_id en elpaso metadata

# 11. Persistencia de sesión
SESSION_ID=$(curl -s -X POST ... | jq -r '.elpaso.session_id')
curl -s -X POST http://localhost:8081/v1/chat/completions \
  -d "{\"model\":\"auto\",\"elpaso\":{\"session_id\":\"$SESSION_ID\"},
       \"messages\":[{\"role\":\"user\",\"content\":\"What did I just say?\"}]}"
# → respuesta referencia el mensaje anterior (contexto activo)

# 12. No stacktraces al usuario
# Parar llama-server y enviar request → debe devolver JSON de error, no crash log

# 13. Documentación
mix docs
# → genera docs sin errores, con todos los módulos públicos documentados

# 14. Hello/world eliminado
grep "def hello" lib/el_paso.ex
# → 0 resultados

# 15. Sin atom injection
grep -rn "String\.to_atom(" lib/ | grep -v "to_existing_atom"
# → 0 resultados
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 9 — CONTEXT.BUILDER: CONECTAR CON CAPAS REALES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 9.1 — Context.Builder.build/3: sustituir hardcoded por capas reales

El `build/3` actual ignora completamente el Manager y el PrefixManager.
Tiene `prefix_block = %{content: "", token_estimate: 0}` y
`context_layers = %{summary: nil, window: [], semantic: []}` hardcodeados.
El pipeline HTTP llama a `Builder.build/3` antes de inferir — si esto
devuelve un prompt vacío, el modelo responde sin contexto.

Reemplazar `lib/el_paso/context/builder.ex` completamente:

```elixir
defmodule ElPaso.Context.Builder do
  @moduledoc """
  Assembles the complete prompt for a session by combining all context layers.

  Layers (in priority order, limited by token budget):
    1. Canonical prefix block (PrefixManager)
    2. Incremental summary (Compression Layer)
    3. Semantic retrieval (Relevance Layer — V1.1)
    4. Sliding window (Recency Layer)
    5. Current user message
  """

  alias ElPaso.Context.{Manager, PrefixManager, Tokenizer}

  defmodule BuiltPrompt do
    @moduledoc "A fully assembled prompt ready to be sent to an inference engine."

    defstruct [:messages, :system, :token_estimate, :budget_used,
               :model_id, :session_id, :built_at]

    @type t :: %__MODULE__{
      messages: [%{role: String.t(), content: String.t()}],
      system: String.t() | nil,
      token_estimate: non_neg_integer(),
      budget_used: %{
        prefix: non_neg_integer(), summary: non_neg_integer(),
        semantic: non_neg_integer(), window: non_neg_integer(),
        current: non_neg_integer()
      },
      model_id: String.t(),
      session_id: String.t(),
      built_at: DateTime.t()
    }
  end

  @doc """
  Builds the complete prompt for a session.

  ## Parameters
    - session_id: existing session identifier
    - current_message: the user's current message (string)
    - context_spec: map with model constraints (max_tokens, reserved_output_tokens,
      supports_system_prompt, chat_template, model_id)

  ## Returns
    - `{:ok, %BuiltPrompt{}}` on success
    - `{:error, reason}` if session not found or budget exhausted
  """
  @spec build(String.t(), String.t(), map()) :: {:ok, BuiltPrompt.t()} | {:error, term()}
  def build(session_id, current_message, context_spec) do
    max_tokens      = context_spec[:max_tokens] || context_spec[:usable_tokens] || 4096
    reserved_output = context_spec[:reserved_for_output] || context_spec[:reserved_output_tokens] || 1024
    usable          = max_tokens - reserved_output

    current_tokens = Tokenizer.estimate(current_message)

    if current_tokens > usable do
      {:error, :message_exceeds_budget}
    else
      remaining = usable - current_tokens

      # Layer 1: canonical prefix
      {prefix_content, prefix_tokens, remaining} = fetch_prefix(session_id, remaining)

      # Layer 2: summary
      {summary_content, summary_tokens, remaining} = fetch_summary(session_id, remaining)

      # Layer 3: semantic (V1.1 — returns [] in V1.0)
      {semantic_msgs, semantic_tokens, remaining} = fetch_semantic(session_id, remaining)

      # Layer 4: sliding window — fit as many messages as budget allows
      {window_msgs, window_tokens} = fetch_window(session_id, remaining)

      messages = assemble_messages(
        prefix_content, context_spec,
        summary_content, semantic_msgs, window_msgs,
        current_message
      )

      system = if context_spec[:supports_system_prompt] != false and prefix_content != "" do
        prefix_content
      else
        nil
      end

      {:ok, %BuiltPrompt{
        messages:       messages,
        system:         system,
        token_estimate: prefix_tokens + summary_tokens + semantic_tokens +
                        window_tokens + current_tokens,
        budget_used: %{
          prefix:   prefix_tokens,
          summary:  summary_tokens,
          semantic: semantic_tokens,
          window:   window_tokens,
          current:  current_tokens
        },
        model_id:   context_spec[:model_id] || "unknown",
        session_id: session_id,
        built_at:   DateTime.utc_now()
      }}
    end
  end

  @doc "Estimates the token budget breakdown without building the full prompt."
  @spec estimate_budget(map(), map()) :: {:ok, map()} | {:error, :insufficient_token_budget}
  def estimate_budget(context_spec, prefix_block) do
    usable        = context_spec[:usable_tokens] || 3072
    prefix_tokens = prefix_block[:token_estimate] || 0

    if prefix_tokens > usable do
      {:error, :insufficient_token_budget}
    else
      {:ok, %{prefix: prefix_tokens, summary: 0, semantic: 0, window: 0, current: 0}}
    end
  end

  # ── Private ───────────────────────────────────────────────────────────────

  defp fetch_prefix(session_id, budget) do
    case PrefixManager.get(session_id) do
      {:ok, %{content: content, token_estimate: tokens}} when tokens <= budget ->
        {content, tokens, budget - tokens}
      {:ok, %{content: content}} ->
        tokens = Tokenizer.estimate(content)
        if tokens <= budget, do: {content, tokens, budget - tokens},
                             else: {"", 0, budget}
      _ ->
        {"", 0, budget}
    end
  end

  defp fetch_summary(session_id, budget) do
    case ElPaso.Context.Storage.get_latest_summary(session_id) do
      {:ok, summary} ->
        tokens = summary.token_estimate || Tokenizer.estimate(summary.content)
        if tokens <= budget do
          {summary.content, tokens, budget - tokens}
        else
          # Truncate summary to fit
          truncated = truncate_to_tokens(summary.content, budget)
          {truncated, budget, 0}
        end
      _ ->
        {nil, 0, budget}
    end
  end

  defp fetch_semantic(_session_id, budget) do
    # V1.0: no semantic retrieval — reserved for V1.1 with pgvector
    {[], 0, budget}
  end

  defp fetch_window(session_id, budget) do
    case Manager.get_session_state(session_id) do
      {:ok, state} ->
        window = state[:window] || []
        # Fill window from newest to oldest within budget
        {msgs, tokens} = fit_messages_in_budget(window, budget)
        {msgs, tokens}
      _ ->
        {[], 0}
    end
  end

  defp fit_messages_in_budget(messages, budget) do
    # Work from newest message backwards
    messages
    |> Enum.reverse()
    |> Enum.reduce_while({[], 0}, fn msg, {acc, used} ->
      content = msg[:content] || ""
      t = Tokenizer.estimate(content)
      if used + t <= budget do
        {:cont, {[msg | acc], used + t}}
      else
        {:halt, {acc, used}}
      end
    end)
  end

  defp assemble_messages(prefix, context_spec, summary, semantic, window, current) do
    messages = []

    # System prompt (only if model supports it)
    messages = if context_spec[:supports_system_prompt] != false and prefix && prefix != "" do
      messages  # system goes in :system field, not in messages list
    else
      if prefix && prefix != "" do
        messages ++ [%{role: "system", content: prefix}]
      else
        messages
      end
    end

    # Summary as assistant context-setter
    messages = if summary do
      messages ++ [%{role: "assistant", content: "[Previous conversation summary: #{summary}]"}]
    else
      messages
    end

    # Semantic context (V1.1)
    messages = messages ++ Enum.map(semantic, &%{role: &1[:role], content: &1[:content]})

    # Window messages (already in order oldest→newest)
    messages = messages ++ Enum.map(window, fn m ->
      %{role: m[:role] || "user", content: m[:content] || ""}
    end)

    # Current user message
    messages ++ [%{role: "user", content: current}]
  end

  defp truncate_to_tokens(text, max_tokens) do
    # Rough truncation: 3 chars ≈ 1 token
    max_chars = max_tokens * 3
    if String.length(text) <= max_chars do
      text
    else
      String.slice(text, 0, max_chars) <> "…"
    end
  end
end
```

Añadir `Tokenizer.estimate/1` como función helper público:

```elixir
# En lib/el_paso/context/tokenizer.ex, añadir:
@doc "Quick token estimate without a registered tokenizer."
@spec estimate(String.t() | nil) :: non_neg_integer()
def estimate(nil), do: 0
def estimate(text) when is_binary(text), do: max(div(String.length(text), 3), 1)
```

✓ Verificación:
```elixir
spec = %{max_tokens: 2048, reserved_for_output: 512, supports_system_prompt: true, model_id: "fast"}
{:ok, built} = ElPaso.Context.Builder.build("session-id", "Hello", spec)
assert is_list(built.messages)
assert List.last(built.messages).content == "Hello"
assert is_integer(built.token_estimate)
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 10 — DOMAIN.ROUTER: CORRECCIONES CRÍTICAS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 10.1 — select_best_model devuelve "default" en lugar de error

```elixir
# ACTUAL — crash en runtime: Enum.max_by([]) lanza Enum.EmptyError
# Y si scores está vacío devuelve "default" (átomo/string que no existe)
defp select_best_model(scores) do
  case Enum.max_by(scores, fn {_model_id, score} -> score end) do
    {model_id, _score} -> model_id
    nil -> "default"   # ← "default" no es un model_id real
  end
end
```

Reemplazar completamente `defp select_best_model/1` y la lógica de route:

```elixir
defp select_best_model(scores) when map_size(scores) == 0 do
  {:error, :no_models_available}
end
defp select_best_model(scores) do
  # Filter out models with :infinity score (too many consecutive errors)
  valid = Enum.reject(scores, fn {_, s} -> s == :infinity or s <= 0 end)
  case Enum.max_by(valid, fn {_, s} -> s end, fn -> nil end) do
    nil               -> {:error, :no_models_available}
    {model_id, _score} -> {:ok, model_id}
  end
end
```

Actualizar `route/4` para manejar el error y devolver `{:ok, model_id, decision}` o
`{:error, :no_models_available}`:

```elixir
def route(request_id, session_id, user_message, overrides \\ %{}) do
  start_us = System.monotonic_time(:microsecond)
  features = extract_features(user_message)

  result =
    if Map.get(overrides, :force_model) || Map.get(overrides, "force_model") do
      {:ok, overrides[:force_model] || overrides["force_model"]}
    else
      model_states = ElPaso.Domain.ModelManager.all_states()
      scores = calculate_scores(model_states, features)
      select_best_model(scores)
    end

  case result do
    {:ok, model_id} ->
      latency_us = System.monotonic_time(:microsecond) - start_us
      decision = %RoutingDecision{
        request_id: request_id,
        session_id: session_id,
        selected_model: model_id,
        runner_up: nil,
        features: features,
        scores: %{},
        reason: "best fit for #{features.task_type}",
        decided_at: DateTime.utc_now(),
        decision_latency_us: latency_us
      }
      ElPaso.Context.Storage.save_routing_decision(decision)
      :telemetry.execute([:elpaso, :router, :decision],
        %{decision_latency_us: latency_us},
        %{request_id: request_id, selected_model: model_id,
          task_type: features.task_type, complexity: features.complexity_score})
      {:ok, model_id, decision}

    {:error, _} = error ->
      error
  end
end
```

## 10.2 — calculate_scores usa campos del ModelState antiguo

El Router actual accede a `model_state.routing_config`, `model_state.complexity_ceiling`
y `model_state.cold_start_estimate_ms` que NO existen en el `ModelState` actual.

El `ModelState` en `Domain.Router` (definido localmente como struct interno) tiene:
`:model_id, :status, :current_queue_depth, :avg_latency_ms, :last_error_at,
:consecutive_errors, :ram_mb, :node` — sin campos de routing.

Después de implementar el `ModelState` ampliado de la Sección 3 del prompt de
correcciones (con `:routing_config, :complexity_ceiling, :cold_start_estimate_ms`),
el Router debe usar `ElPaso.Domain.ModelState` en lugar del struct local.

Acciones concretas:
1. Eliminar `defmodule ModelState` del interior de `Domain.Router`.
2. Añadir `alias ElPaso.Domain.ModelState` al módulo.
3. Actualizar `calculate_scores/2` para leer los campos con defaults seguros:

```elixir
defp calculate_scores(model_states, features) do
  config = ElPaso.Config.Loader.get()
  max_errors = get_in(config, [:routing, :max_consecutive_errors_before_exclude]) || 3

  model_states
  |> Enum.filter(&(&1.status in [:hot, :warming]))
  |> Enum.reduce(%{}, fn state, acc ->
    score = if state.consecutive_errors >= max_errors do
      # Effectively exclude this model
      0
    else
      affinity = ElPaso.Config.Loader.get_affinity(
        state.model_id, to_string(features.task_type))
      complexity_ceiling = Map.get(state, :complexity_ceiling, 1.0)

      # Penalize if task complexity exceeds model ceiling
      ceiling_factor = if features.complexity_score > complexity_ceiling do
        max(0.1, 1.0 - (features.complexity_score - complexity_ceiling))
      else
        1.0
      end

      # Penalize cold/warming models
      status_factor = if state.status == :hot, do: 1.0, else: 0.6

      # Penalize high queue depth
      queue_factor = max(0.1, 1.0 - state.current_queue_depth * 0.1)

      affinity * ceiling_factor * status_factor * queue_factor
    end

    Map.put(acc, state.model_id, score)
  end)
end
```

✓ Verificación:
```elixir
# Con modelos registrados y al menos uno hot:
{:ok, model_id, decision} = ElPaso.Domain.Router.route("req-1", "sess-1", "Write a function")
assert is_binary(model_id)
# Sin modelos:
{:error, :no_models_available} = ElPaso.Domain.Router.route("req-2", "sess-2", "hello")
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 11 — SUPERVISORES VACÍOS: RELLENAR CHILDREN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 11.1 — Event.Supervisor: añadir hijos reales

```elixir
defmodule ElPaso.Event.Supervisor do
  @moduledoc "Supervisor for event handling and error reporting."
  use Supervisor

  def start_link(args \\ []) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl Supervisor
  def init(_args) do
    children = [
      # Error event logger — receives telemetry events and logs/persists them
      ElPaso.Event.ErrorLogger,
      # Inference event handler — updates ModelWorker stats on completion
      ElPaso.Event.InferenceHandler
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

Crear `lib/el_paso/event/error_logger.ex`:

```elixir
defmodule ElPaso.Event.ErrorLogger do
  @moduledoc "Attaches to telemetry and logs error events."
  use GenServer
  require Logger

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def init(:ok) do
    :telemetry.attach_many(
      "elpaso-error-logger",
      [
        [:elpaso, :engine, :execute, :error],
        [:elpaso, :inference, :error]
      ],
      &handle_event/4,
      nil
    )
    {:ok, :ok}
  end

  def terminate(_reason, _state) do
    :telemetry.detach("elpaso-error-logger")
  end

  defp handle_event(event, measurements, metadata, _config) do
    Logger.warning("[Event] #{inspect(event)} — #{inspect(metadata)} — #{inspect(measurements)}")
  end
end
```

Crear `lib/el_paso/event/inference_handler.ex`:

```elixir
defmodule ElPaso.Event.InferenceHandler do
  @moduledoc "Updates ModelWorker stats when an inference completes."
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def init(:ok) do
    :telemetry.attach_many(
      "elpaso-inference-handler",
      [
        [:elpaso, :inference, :complete],
        [:elpaso, :inference, :error]
      ],
      &handle_event/4,
      nil
    )
    {:ok, :ok}
  end

  def terminate(_reason, _state) do
    :telemetry.detach("elpaso-inference-handler")
  end

  defp handle_event([:elpaso, :inference, :complete], measurements, metadata, _) do
    ElPaso.Domain.ModelManager.record_call_result(
      metadata.model_id,
      measurements.latency_ms,
      :success
    )
  end

  defp handle_event([:elpaso, :inference, :error], _measurements, metadata, _) do
    ElPaso.Domain.ModelManager.record_call_result(
      metadata[:model_id] || "unknown",
      0,
      :error
    )
  end
end
```

## 11.2 — SummarizationSupervisor: añadir Task.Supervisor

```elixir
defmodule ElPaso.Context.SummarizationSupervisor do
  @moduledoc "Supervises async summarization tasks."
  use Supervisor

  def start_link(args \\ []) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl Supervisor
  def init(_args) do
    children = [
      # Dynamic task supervisor for async summarization jobs
      {Task.Supervisor, name: ElPaso.Context.SummarizationTaskSupervisor}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

Actualizar `SummarizationWorker.trigger_async/4` para usar el supervisor:

```elixir
def trigger_async(session_id, messages, existing_summary, opts \\ []) do
  Task.Supervisor.start_child(
    ElPaso.Context.SummarizationTaskSupervisor,
    fn -> do_summarize(session_id, messages, existing_summary, opts) end
  )
end
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 12 — ENGINES FALTANTES Y DISPATCHER COMPLETO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 12.1 — Engine.VLLM: adapter para vLLM (OpenAI-compatible)

Crear `lib/el_paso/engine/vllm.ex`:

```elixir
defmodule ElPaso.Engine.VLLM do
  @moduledoc "Engine adapter for vLLM. API-compatible with OpenAI."
  @behaviour ElPaso.Engine

  # vLLM exposes an OpenAI-compatible API — reuse LlamaServer adapter
  defdelegate name(),                                  to: __MODULE__, as: :_name
  defdelegate type(),                                  to: __MODULE__, as: :_type
  defdelegate infer(prompt, params, config),           to: ElPaso.Engine.LlamaServer
  defdelegate stream(prompt, params, config, cb),      to: ElPaso.Engine.LlamaServer
  defdelegate prepare_prefix(prefix, config),          to: ElPaso.Engine.LlamaServer
  defdelegate format_messages(messages, ctx),          to: ElPaso.Engine.LlamaServer

  @impl true
  def name, do: :vllm

  @impl true
  def type, do: :local_process

  @impl true
  def health_check(config) do
    url = "#{config[:base_url] || "http://localhost:8000/v1"}/models"
    case Finch.build(:get, url) |> Finch.request(ElPasoFinch, receive_timeout: 5_000) do
      {:ok, %{status: 200}} -> :ok
      _                     -> {:error, :vllm_unavailable}
    end
  rescue
    _ -> {:error, :vllm_unavailable}
  end
end
```

## 12.2 — Engine.Anthropic: adapter para API de Anthropic

Crear `lib/el_paso/engine/anthropic.ex`:

```elixir
defmodule ElPaso.Engine.Anthropic do
  @moduledoc "Engine adapter for Anthropic Claude API."
  @behaviour ElPaso.Engine
  require Logger
  alias ElPaso.Engine.{Response, Chunk}

  @anthropic_api "https://api.anthropic.com/v1"
  @anthropic_version "2023-06-01"

  @impl true
  def name, do: :anthropic

  @impl true
  def type, do: :remote_api

  @impl true
  def infer(prompt, params, config) do
    start = System.monotonic_time(:millisecond)
    body  = build_request(prompt, params, false)
    url   = "#{config[:base_url] || @anthropic_api}/messages"

    case http_post(url, body, config[:api_key]) do
      {:ok, %{status: 200, body: resp_body}} ->
        case Jason.decode(resp_body) do
          {:ok, data} ->
            content = data["content"]
              |> List.first(%{})
              |> Map.get("text", "")
            {:ok, %Response{
              content:            content,
              finish_reason:      String.to_atom(data["stop_reason"] || "end_turn"),
              prompt_tokens:      get_in(data, ["usage", "input_tokens"])  || 0,
              completion_tokens:  get_in(data, ["usage", "output_tokens"]) || 0,
              latency_ms:         System.monotonic_time(:millisecond) - start
            }}
          _ -> {:error, :invalid_json}
        end
      {:ok, %{status: 401}} -> {:error, :unauthorized}
      {:ok, %{status: 429}} -> {:error, :rate_limited}
      {:ok, %{status: s}}   -> {:error, {:http_error, s}}
      {:error, r}           -> {:error, r}
    end
  end

  @impl true
  def stream(prompt, params, config, chunk_callback) do
    body = build_request(prompt, params, true)
    url  = "#{config[:base_url] || @anthropic_api}/messages"

    Finch.build(:post, url, headers(config[:api_key]), Jason.encode!(body))
    |> Finch.stream(ElPasoFinch, fn
      {:data, data}, acc ->
        data
        |> String.split("\n", trim: true)
        |> Enum.each(fn line ->
          case line do
            "data: " <> json ->
              case Jason.decode(json) do
                {:ok, %{"type" => "content_block_delta",
                        "delta" => %{"text" => text}}} ->
                  chunk_callback.(%Chunk{content: text, done: false})
                {:ok, %{"type" => "message_stop"}} ->
                  chunk_callback.(%Chunk{content: "", done: true})
                _ -> :ok
              end
            _ -> :ok
          end
        end)
        {:cont, acc}
      _, acc -> {:cont, acc}
    end, [])
    |> case do
      {:ok, _} -> :ok
      err      -> err
    end
  end

  @impl true
  def prepare_prefix(prefix, _config), do: prefix

  @impl true
  def health_check(config) do
    url = "#{config[:base_url] || @anthropic_api}/models"
    case Finch.build(:get, url, headers(config[:api_key]))
         |> Finch.request(ElPasoFinch, receive_timeout: 5_000) do
      {:ok, %{status: 200}} -> :ok
      _                     -> {:error, :anthropic_unavailable}
    end
  rescue
    _ -> {:error, :anthropic_unavailable}
  end

  @impl true
  def format_messages(messages, _ctx), do: messages

  defp build_request(prompt, params, stream) do
    messages = Enum.reject(prompt.messages, &(&1[:role] == "system"))
    %{
      model:      params[:model] || "claude-3-5-haiku-latest",
      messages:   messages,
      stream:     stream,
      max_tokens: params[:max_tokens] || 1024,
      system:     prompt.system
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp http_post(url, body, api_key) do
    case Finch.build(:post, url, headers(api_key), Jason.encode!(body))
         |> Finch.request(ElPasoFinch, receive_timeout: 120_000) do
      {:ok, r} -> {:ok, %{status: r.status, body: r.body}}
      err      -> err
    end
  end

  defp headers(api_key) do
    [
      {"content-type",       "application/json"},
      {"x-api-key",          api_key || ""},
      {"anthropic-version",  @anthropic_version}
    ]
  end
end
```

## 12.3 — Engine.Dispatcher: conectar Engine.Registry para plugins custom

El `resolve_engine/1` actual no busca en el Registry cuando el engine no es conocido.
Corregir para cerrar el ciclo:

```elixir
defp resolve_engine(engine_name) when is_binary(engine_name) do
  case engine_name do
    "llama_server"  -> {:ok, ElPaso.Engine.LlamaServer}
    "llama-server"  -> {:ok, ElPaso.Engine.LlamaServer}
    "vllm"          -> {:ok, ElPaso.Engine.VLLM}
    "openai"        -> {:ok, ElPaso.Engine.OpenAI}
    "anthropic"     -> {:ok, ElPaso.Engine.Anthropic}
    "ollama"        -> {:ok, ElPaso.Engine.Ollama}
    "airllm"        -> {:ok, ElPaso.Engine.AirLLMWrapper}
    "airllm_wrapper"-> {:ok, ElPaso.Engine.AirLLMWrapper}
    other           ->
      atom = try do String.to_existing_atom(other) rescue _ -> nil end
      if atom do
        ElPaso.Engine.Registry.get(atom)
      else
        {:error, {:unknown_engine, other}}
      end
  end
end
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 13 — MIX TASK DISPATCHER: ACTUALIZAR CON NUEVOS COMANDOS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 13.1 — Mix.Tasks.Elpaso: ampliar el dispatcher raíz

El task raíz actual solo conoce los comandos originales. Reemplazar `run/1`:

```elixir
defmodule Mix.Tasks.Elpaso do
  use Mix.Task

  @shortdoc "ElPaso management commands"
  @moduledoc """
  ElPaso management commands.

  ## Engine management

      mix elpaso.engine.add       Register a new inference engine
      mix elpaso.engine.list      List registered engines
      mix elpaso.engine.remove    Remove a registered engine
      mix elpaso.engine.test      Test connectivity to an engine

  ## Model management

      mix elpaso.model.add        Register a new model
      mix elpaso.model.list       List registered models
      mix elpaso.model.remove     Remove a registered model
      mix elpaso.model.start      Start a model's engine
      mix elpaso.model.stop       Stop a model's engine

  ## Skills & MCP

      mix elpaso.skill.add        Register a skill module
      mix elpaso.skill.list       List registered skills
      mix elpaso.mcp.add          Register an MCP server
      mix elpaso.mcp.list         List registered MCP servers
      mix elpaso.mcp.test         Test an MCP server connection

  ## Diagnostics

      mix elpaso.router.stats     Show routing statistics
      mix elpaso.router.tune      Apply auto-tune adjustments
      mix elpaso.bench            Run inference benchmark

  ## Configuration

      mix elpaso.init             Interactive setup wizard
      mix elpaso.config.show      Show current configuration
      mix elpaso.config.validate  Validate elpaso.conf
      mix elpaso.config.reload    Reload config from disk

  ## Context

      mix elpaso.context.export   Export context for a session
  """

  def run(["engine" | rest]),   do: Mix.Task.run("elpaso.engine.#{hd(rest)}", tl(rest))
  def run(["model" | rest]),    do: Mix.Task.run("elpaso.model.#{hd(rest)}", tl(rest))
  def run(["skill" | rest]),    do: Mix.Task.run("elpaso.skill.#{hd(rest)}", tl(rest))
  def run(["mcp" | rest]),      do: Mix.Task.run("elpaso.mcp.#{hd(rest)}", tl(rest))
  def run(["router" | rest]),   do: Mix.Task.run("elpaso.router.#{hd(rest)}", tl(rest))
  def run(["context" | rest]),  do: Mix.Task.run("elpaso.context.#{hd(rest)}", tl(rest))
  def run(["config" | rest]),   do: Mix.Task.run("elpaso.config.#{hd(rest)}", tl(rest))
  def run(["bench" | rest]),    do: Mix.Task.run("elpaso.bench", rest)
  def run(["init" | rest]),     do: Mix.Task.run("elpaso.init", rest)
  def run(["--help" | _]),      do: Mix.Task.run("help", ["elpaso"])
  def run(["-h" | _]),          do: Mix.Task.run("help", ["elpaso"])
  def run([]),                  do: Mix.Task.run("help", ["elpaso"])
  def run([unknown | _]) do
    Mix.shell().error("Unknown command: #{unknown}")
    Mix.shell().info("Run 'mix help elpaso' for available commands.")
  end
end
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 14 — ARCHIVOS DE CONFIGURACIÓN ELIXIR FALTANTES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 14.1 — config/config.exs

```elixir
import Config

config :elpaso, ElPaso.Repo,
  url: System.get_env("DATABASE_URL", "postgresql://localhost/elpaso_dev"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
  socket_options: []

config :elpaso, :ecto_repos, [ElPaso.Repo]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :session_id, :model_id]
```

## 14.2 — config/test.exs

```elixir
import Config

config :elpaso, ElPaso.Repo,
  url: System.get_env("TEST_DATABASE_URL", "postgresql://localhost/elpaso_test"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5

config :logger, level: :warning
```

## 14.3 — config/runtime.exs (opcional, para releases)

```elixir
import Config

if config_env() == :prod do
  config :elpaso, ElPaso.Repo,
    url: System.fetch_env!("DATABASE_URL"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))
end
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 15 — VISIBILIDAD DE FUNCIONES ANTES DE DOCUMENTAR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 15.1 — Funciones que deben ser defp (no forman parte de la API pública)

Revisar TODOS los módulos y aplicar:

**Domain.Router** — hacer privados:
- `extract_features/1` → `defp`
- `detect_task_type/1` → `defp`
- `calculate_complexity_score/3` → `defp`
- `detect_language/1` → `defp`
- `calculate_scores/2` → `defp`
- `extract_image_features/1` → `defp`

**Context.Builder** — hacer privados:
- `fetch_prefix/2`, `fetch_summary/2`, `fetch_semantic/2`, `fetch_window/2` → `defp`
- `assemble_messages/6`, `fit_messages_in_budget/2`, `truncate_to_tokens/2` → `defp`

**Context.Storage** — hacer privados:
- `estimate_tokens/1` → `defp`
- `safe_to_atom/1` (si existe) → `defp` con `String.to_existing_atom`

**Engine.LlamaServer** — hacer privados:
- `build_request_body/4`, `http_post/3`, `headers/1`, `parse_sse_chunks/2` → `defp`

**Domain.ModelWorker** — hacer privados:
- `launch_engine_process/2`, `perform_health_check/1`, `maybe_stop_idle/1` → `defp`
- `stop_engine/1`, `notify_waiters/2`, `extract_port/1`, `percentile_95/1` → `defp`

**HTTP.Server** — hacer privados:
- `handle_non_streaming/9`, `handle_streaming/8`, `error_response/4` → `defp`
- `last_user_message/1`, `build_context_spec/1`, `generate_request_id/0` → `defp`

**Regla general**: si una función no aparece en ningún `@doc` público ni se
llama desde fuera del módulo, es `defp`. Ejecutar después:

```bash
mix docs 2>&1 | grep "undefined @doc"
# → debe devolver 0 resultados
```


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 16 — GAPS DESCUBIERTOS EN REVISIÓN FINAL (LECTURA LÍNEA A LÍNEA)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Esta sección cubre problemas que no estaban en ninguna sección anterior.
Son descubrimientos de la revisión exhaustiva archivo por archivo.

## 16.1 — Engine behaviour: referencia a módulo inexistente

```elixir
# ACTUAL en lib/el_paso/engine.ex:
@callback infer(
  prompt :: ElPaso.Context.BuiltPrompt.t(),   # NO EXISTE este módulo
  ...
@callback prepare_prefix(
  prefix :: ElPaso.Context.PrefixBlock.t(),   # NO EXISTE este módulo
```

`ElPaso.Context.BuiltPrompt` no existe — está definido como
`ElPaso.Context.Builder.BuiltPrompt`. Lo mismo para `PrefixBlock`,
que está en `ElPaso.Context.PrefixManager.PrefixBlock`.

Corrección en `lib/el_paso/engine.ex`:
```elixir
@callback infer(
  prompt :: ElPaso.Context.Builder.BuiltPrompt.t(),
  params :: map(),
  config :: map()
) :: {:ok, ElPaso.Engine.Response.t()} | {:error, term()}

@callback prepare_prefix(
  prefix :: ElPaso.Context.PrefixManager.PrefixBlock.t(),
  config :: map()
) :: term()
```

✓ Verificación: `mix compile --warnings-as-errors` sin undefined module warnings.

---

## 16.2 — Application.start/2: alias a módulo inexistente

```elixir
# ACTUAL:
alias ModelDownloaderRegistry   # módulo que NO existe en el codebase
# Después llama:
ModelDownloaderRegistry.init()  # crash en runtime
```

`ModelDownloaderRegistry` no existe. `ElPaso.Downloader.ModelDownloader`
sí existe, pero no tiene `Registry`. La llamada a `.init()` crashea.

Corrección en `lib/el_paso/application.ex`:
- Eliminar el `alias ModelDownloaderRegistry`
- Eliminar la llamada `ModelDownloaderRegistry.init()`
- Eliminar `ElPaso.Security.RateLimiter.init()` de Application.start/2
  (ya se maneja en el propio módulo como hijo supervisado en la Sección 1.2)

---

## 16.3 — Application.start/2: usa SessionSupervisor (children vacíos) en lugar de Manager

```elixir
# ACTUAL en Application:
ElPaso.Context.SessionSupervisor,   # children: [] — no hace nada

# Context.Manager (el que tiene la lógica real) NO está en el árbol
```

`SessionSupervisor` tiene `children: []`. El `Context.Manager` (GenServer
con ETS) no está en el árbol de supervisión en absoluto, por lo que
`:session_states` no está inicializado cuando llega el primer request.
Resultado: `ArgumentError` en cualquier `get_session_state` call.

Corrección: reemplazar `ElPaso.Context.SessionSupervisor` por
`ElPaso.Context.Manager` en el árbol (ya cubierto en Sección 1.2).
Mantener `SessionSupervisor` como archivo si se necesita para tests,
pero no en el árbol OTP de producción.

---

## 16.4 — Context.Manager no tiene `name:` en start_link

```elixir
# ACTUAL:
def start_link(args) do
  GenServer.start_link(__MODULE__, args)   # Sin name: → no registrado
end
```

Sin `name:`, el GenServer no es alcanzable por nombre. Cualquier llamada
a `ElPaso.Context.Manager.get_session_state/1` desde fuera del proceso
usará el pid, que no tenemos. El módulo no tiene API pública que use pid.

Corrección:
```elixir
def start_link(args) do
  GenServer.start_link(__MODULE__, args, name: __MODULE__)
end
```

Además, añadir `handle_call` para la API pública (actualmente el Manager
usa funciones que acceden a ETS directamente sin pasar por GenServer,
lo que es correcto para lecturas concurrentes, pero `get_or_create_session`
necesita serialización para evitar race conditions al crear):

```elixir
# Las funciones que solo leen de ETS pueden quedarse como llamadas directas:
def get_session_state(session_id) do ... :ets.lookup ... end  # OK directo
def update_session_state(session_id, state) do ... :ets.insert ... end  # OK directo

# get_or_create_session debe serializarse vía GenServer para evitar
# que dos requests concurrentes creen la misma sesión dos veces:
def get_or_create_session(session_id \\ nil, user_id \\ nil) do
  GenServer.call(__MODULE__, {:get_or_create, session_id, user_id}, 10_000)
end

@impl true
def handle_call({:get_or_create, session_id, user_id}, _from, state) do
  result = do_get_or_create(session_id, user_id)
  {:reply, result, state}
end

defp do_get_or_create(session_id, user_id) do
  # ... lógica actual de get_or_create_session ...
end
```

✓ Verificación:
```elixir
{:ok, sid, _state} = ElPaso.Context.Manager.get_or_create_session()
assert is_binary(sid)
```

---

## 16.5 — Context.Manager.reload_session: siempre devuelve {:error, :not_found}

```elixir
# ACTUAL:
def reload_session(_session_id) do
  # Stub: Storage.get_session returns {:error, :not_found}
  {:error, :not_found}
end
```

Implementar con la Storage real (que se corrige en Sección 4.1 del
prompt de correcciones):

```elixir
def reload_session(session_id) do
  case ElPaso.Context.Storage.get_session(session_id) do
    {:ok, session} ->
      session_state = %SessionState{
        session_id: session_id,
        context_mode: to_string(session.context_mode),
        window: [],
        window_token_count: 0,
        created_at: session.created_at,
        last_active_at: session.last_active_at,
        summarization_in_progress: false,
        semantic_retrieval_enabled: false
      }
      :ets.insert(:session_states,
        {session_id, session_state, System.monotonic_time(:millisecond)})
      {:ok, session_state}

    {:error, :not_found} = error ->
      error

    {:error, _} ->
      {:error, :not_found}
  end
end
```

---

## 16.6 — Context.Manager.maybe_prefix_session_id llama Config.Loader.get() devolviendo nil keys

```elixir
# ACTUAL:
auth_enabled = Map.get(ElPaso.Config.Loader.get(), :auth, %{}) |> Map.get(:enabled, false)
```

Después de reescribir `Config.Loader.get()` en la Sección 1.1, la config
devuelve `%{system: %{auth_enabled: false}, ...}` — ya no tiene clave `:auth`.

Corrección:
```elixir
defp auth_enabled? do
  ElPaso.Config.auth_enabled?()  # usa la función de la fachada Config
end

# Y en maybe_prefix_session_id:
if auth_enabled?() and user_id do ... end
```

---

## 16.7 — Router.route/4: acceso a overrides.force_model puede crashear

```elixir
# ACTUAL:
if overrides.force_model do   # crash si overrides es un mapa con string keys
```

El router se llama desde el HTTP handler con `overrides` que puede ser
`%{}`, un `%SessionOverrides{}` struct, o un mapa con string keys.
El acceso `overrides.force_model` solo funciona si es un struct o mapa
con atom keys.

Corrección:
```elixir
force_model = Map.get(overrides, :force_model) ||
              Map.get(overrides, "force_model") ||
              (is_struct(overrides) && Map.get(overrides, :force_model))

if force_model do
  # ...
end
```

---

## 16.8 — CLI.run parse_options: String.to_atom desde input de usuario

```elixir
# ACTUAL en lib/el_paso/cli.ex:
defp parse_options(args) do
  Enum.reduce(args, %{}, fn arg, acc ->
    case String.split(arg, "=", parts: 2) do
      [key, value] -> Map.put(acc, String.to_atom(key), value)  # ATOM INJECTION
      [key]        -> Map.put(acc, String.to_atom(key), true)   # ATOM INJECTION
    end
  end)
end
```

Corrección:
```elixir
@known_option_keys ~w(
  limit period model session dry_run force revert_auto
  output format quiet verbose help version
)

defp parse_options(args) do
  Enum.reduce(args, %{}, fn arg, acc ->
    case String.split(arg, "=", parts: 2) do
      ["--" <> key, value] -> put_known_key(acc, key, value)
      ["--" <> key]        -> put_known_key(acc, key, true)
      [key, value]         -> put_known_key(acc, key, value)
      [key]                -> put_known_key(acc, key, true)
    end
  end)
end

defp put_known_key(acc, key, value) do
  atom_key = try do String.to_existing_atom(key) rescue _ -> nil end
  if atom_key && to_string(atom_key) in @known_option_keys do
    Map.put(acc, atom_key, value)
  else
    acc  # ignorar claves desconocidas
  end
end
```

---

## 16.9 — Security.Auth.authenticate llama Config.Loader.get().auth: campo inexistente

```elixir
# ACTUAL:
auth_config = ElPaso.Config.Loader.get().auth   # .auth no existe en la config nueva
enabled = Map.get(auth_config, :enabled, false)
users = Map.get(auth_config, :users, [])
```

Tras reescribir Config, no hay campo `.auth`. Hay `system.auth_enabled` y
`system.allow_anonymous`.

Corrección:
```elixir
def authenticate(api_key) do
  enabled         = ElPaso.Config.auth_enabled?()
  allow_anonymous = ElPaso.Config.allow_anonymous?()
  users           = get_in(ElPaso.Config.Loader.get(), [:auth, :users]) || []

  cond do
    not enabled                  -> {:ok, "anonymous"}
    api_key == nil and allow_anonymous -> {:ok, "anonymous"}
    api_key == nil               -> {:error, :missing_api_key}
    true ->
      case find_user_by_key(users, api_key) do
        nil  -> {:error, :invalid_api_key}
        user -> {:ok, user[:id] || user["id"]}
      end
  end
end
```

---

## 16.10 — HTTP.Server: Plug.Router no tiene plug :fetch_query_params

```elixir
# ACTUAL:
use Plug.Router
plug(:match)
plug(:dispatch)
# Falta: plug :fetch_query_params
# Falta: plug :fetch_session (si se usan sesiones)
# Falta: plug ElPaso.HTTP.AuthPlug cuando auth está habilitado
```

Corrección al inicio de HTTP.Server:
```elixir
use Plug.Router

plug Plug.Logger
plug :fetch_query_params
plug :match
plug :dispatch
```

Y añadir AuthPlug condicionalmente (no en compile time, sino en runtime):
```elixir
# En Application.start/2 o en HTTP.Server.init/1:
plug_stack = if ElPaso.Config.auth_enabled?() do
  [Plug.Logger, :fetch_query_params, ElPaso.HTTP.AuthPlug, :match, :dispatch]
else
  [Plug.Logger, :fetch_query_params, :match, :dispatch]
end
```

Para simplificar en V1.0: añadir siempre AuthPlug pero hacer que sea
transparent (no bloquea) si `auth_enabled?()` es false. AuthPlug ya
hace esto correctamente — si `authenticate(nil)` devuelve `{:ok, "anonymous"}`
cuando auth está deshabilitado.

---

## 16.11 — HTTP.Server: json/2 helper usa `resp` en lugar de `send_resp`

```elixir
# ACTUAL:
defp json(conn, data) do
  conn
  |> put_resp_content_type("application/json")
  |> resp(200, Jason.encode!(data))   # resp/3 no envía, solo prepara
end

# El endpoint /infer usa:
conn |> put_status(200) |> json(%{...})
# put_status + resp sin send_resp → respuesta nunca enviada al cliente
```

Corrección:
```elixir
defp json(conn, data) do
  conn
  |> put_resp_content_type("application/json")
  |> send_resp(200, Jason.encode!(data))
end
```

---

## 16.12 — HTTP.Server: Plug.Cowboy.http con args incorrectos

```elixir
# ACTUAL en HTTP.Server:
def start_link(_args) do
  {:ok, _} = Plug.Cowboy.http(__MODULE__, [])
  {:ok, self()}
end
```

Esto crea un segundo servidor HTTP (además del que arranca Application).
Es dead code que nunca se llama desde Application (Application usa
`{Plug.Cowboy, scheme: :http, plug: ..., options: [port: ...]}` directamente).
Eliminar `start_link/1` de `HTTP.Server`.

---

## 16.13 — ChatTemplate: API incorrecta — no tiene format/3

```elixir
# ACTUAL en lib/el_paso/engine/chat_template.ex:
def format_message(%{role: role, content: content}) do ... end
def format_messages(messages) do ... end
def build_prompt(system_prompt, user_prompt) do ... end

# Lo que el Dispatcher (Sección 12) necesita:
def format(messages, system_prompt, template_atom) do ... end
# → {:passthrough, messages} | {:formatted, string}
```

Reemplazar `lib/el_paso/engine/chat_template.ex` completamente con la
implementación de la Sección 5.1 del prompt de correcciones (los 5 templates:
gemma, chatml, llama3, mistral, openai/anthropic passthrough).

---

## 16.14 — Engine.Ollama: es un struct, no un engine behaviour

```elixir
# ACTUAL:
def new(base_url) do
  %{base_url: base_url, api_key: "ollama"}  # Devuelve un mapa, no implementa behaviour
end
def infer(_adapter, _prompt) do
  {:ok, "response from ollama"}   # Devuelve string hardcodeado, aridad incorrecta
end
```

`ElPaso.Engine.Ollama` debe implementar `@behaviour ElPaso.Engine` con
la aridad correcta: `infer(prompt, params, config)`, no `infer(adapter, prompt)`.

Reemplazar con la implementación de la Sección 5.5 del prompt de correcciones
(que delega en LlamaServer ya que son API-compatible).

---

## 16.15 — RouterStats.aggregate siempre devuelve struct vacío

```elixir
# ACTUAL:
def aggregate(_since) do
  %__MODULE__{}   # siempre vacío
end
```

`RouterStats.aggregate/1` es llamado por `RouterStats CLI command` y por
el Dashboard. Siempre devuelve ceros.

Implementación real usando Storage:

```elixir
def aggregate(since) do
  decisions = ElPaso.Context.Storage.query_routing_decisions(since: since, with_outcome: true)

  by_model = Enum.group_by(decisions, & &1[:selected_model])
  by_task  = Enum.group_by(decisions, & &1[:task_type])

  total      = length(decisions)
  errors     = Enum.count(decisions, &(&1[:outcome] == :error or &1[:outcome] == "error"))
  retries    = Enum.count(decisions, &(&1[:outcome] == :retry or &1[:outcome] == "retry"))

  %__MODULE__{
    total_decisions:  total,
    fallback_count:   retries,
    fallback_rate_pct: if(total > 0, do: Float.round(retries / total * 100, 1), else: 0.0),
    error_count:      errors,
    by_model:         Map.new(by_model, fn {k, v} -> {k, length(v)} end),
    by_task_type:     Map.new(by_task,  fn {k, v} -> {k, length(v)} end),
    cold_starts:      0   # requiere telemetry en V1.1
  }
end
```

---

## 16.16 — EmbeddingClient: todos los métodos devuelven {:error, :not_configured}

El `EmbeddingClient` es necesario para la capa semántica (V1.1), pero
actualmente bloquea si se llama. En V1.0 es aceptable, pero debe existir
una forma de activarlo cuando haya un modelo de embeddings disponible.

Para V1.0: documentar con `@doc false` o añadir `@moduledoc "Not implemented in V1.0."`.
No es un bug bloqueante, pero debe documentarse explícitamente como pendiente.

---

## 16.17 — Domain.AutoTuner.cluster_mode? no existe en Config

```elixir
# ACTUAL en AutoTuner:
if ElPaso.Config.cluster_mode?() do   # cluster_mode?/0 no existe en Config
```

`ElPaso.Config` tiene `cluster_enabled?/0`, no `cluster_mode?/0`.

Corrección en todos los módulos que usen `cluster_mode?()`:
```elixir
ElPaso.Config.cluster_enabled?()
```

Hacer búsqueda global:
```bash
grep -rn "cluster_mode?" lib/
# Corregir cada ocurrencia a cluster_enabled?()
```

---

## 16.18 — Domain.Router.Cluster: condición de cortocircuito incorrecta

```elixir
# ACTUAL:
if Enum.empty?(NodeRegistry.all_nodes()) do
  local_with_node   # devuelve, pero NO hace return — Elixir no tiene return
end                 # el código continúa y ejecuta el bloque de nodos remotos igualmente
```

Elixir no tiene `return`. El `if` sin `else` devuelve el valor pero no
interrumpe el flujo. El código continúa ejecutando el bloque de nodos remotos.

Corrección:
```elixir
if Enum.empty?(NodeRegistry.all_nodes()) do
  local_with_node
else
  remote = NodeRegistry.all_nodes()
    |> Enum.filter(...)
    |> Task.async_stream(...)
    |> Enum.flat_map(...)

  local_with_node ++ remote
end
```

---

## 16.19 — HTTP.Dashboard GET /api/state: URL no coincide con JavaScript

```javascript
// ACTUAL en el HTML del Dashboard:
fetch('/dashboard/api/state')   // pide /dashboard/api/state

// ACTUAL en Dashboard router:
get "/api/state" do             // registra /api/state (sin /dashboard/)
```

El Dashboard está montado como sub-router desde `HTTP.Server` con:
```elixir
get "/dashboard" do
  ElPaso.HTTP.Dashboard.call(conn, [])
end
```

Esto monta el Dashboard en `/dashboard`, pero las rutas internas del
Dashboard son relativas al módulo, no a la URL de montaje. El fetch
`/dashboard/api/state` no matcheará con `get "/api/state"`.

Corrección — dos opciones:
- **Opción A**: cambiar el JS a `fetch('/dashboard/api/state')` y registrar
  `get "/dashboard/api/state"` en HTTP.Server (más simple).
- **Opción B**: usar `forward "/dashboard", to: Dashboard` en HTTP.Server
  (requiere Plug.Router.forward que sí existe).

Recomendación: Opción A, más simple para V1.0:
```elixir
# En HTTP.Server, reemplazar:
get "/dashboard" do
  ElPaso.HTTP.Dashboard.call(conn, [])
end

# Por:
forward "/dashboard", to: ElPaso.HTTP.Dashboard
```

Y en Dashboard.html: cambiar `fetch('/dashboard/api/state')` por `fetch('/api/state')`.
O mantener el forward y que Dashboard registre rutas sin prefijo.

---

## 16.20 — Security.RateLimiter: init() crea tabla ETS sin start_link

```elixir
# ACTUAL:
def init() do
  :ets.new(:rate_limiter, [:named_table, :public, :set])
end
# No tiene start_link — no puede ser hijo del supervisor
```

Y en Application.start/2 (actual):
```elixir
ElPaso.Security.RateLimiter.init()   # llamado directamente, fuera del árbol
```

Si el proceso que llama a `init()` muere, la tabla ETS muere con él.
Si `init()` se llama dos veces, lanza `ArgumentError: ETS table already exists`.

Corrección: convertir a GenServer (o usar Agent) que sea hijo supervisado:

```elixir
defmodule ElPaso.Security.RateLimiter do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    :ets.new(:rate_limiter, [:named_table, :public, :set,
      {:write_concurrency, true}, {:read_concurrency, true}])
    {:ok, :ok}
  end

  # check_rate/2 sigue siendo una función pública que accede a ETS directamente
  # (sin pasar por el GenServer para máximo rendimiento)
  def check_rate(user_id, max_rpm) do
    # ... implementación actual ...
  end
end
```

---

## 16.21 — Telemetry.Store: no está en el árbol de Application actual

```elixir
# ACTUAL en Application:
ElPaso.Telemetry.Store,   # SÍ está en el árbol — OK

# PERO: Store.prefix_cache_hit_ratio/0 accede a ETS que puede no existir
# si Store no arrancó aún cuando Dashboard lo consulta
```

Verificar que `Store.prefix_cache_hit_ratio/0` tiene un rescue:
```elixir
def prefix_cache_hit_ratio do
  GenServer.call(__MODULE__, :prefix_cache_hit_ratio)
rescue
  _ -> 0.0
catch
  :exit, _ -> 0.0
end
```

---

## 16.22 — Plugin.Loader: no está en el árbol OTP

```elixir
# El módulo existe en lib/el_paso/plugin/loader.ex
# Pero no aparece en Application.start/2

# Plugin.Loader carga plugins al arrancar — si no está supervisado,
# los plugins nunca se cargan
```

A�adir al árbol de Application (ya corregido en Sección 1.2, verificar
que la lista de children incluye `ElPaso.Plugin.Loader`).

Si Plugin.Loader no necesita ser un proceso (solo ejecuta código al cargarse),
convertir en una llamada en Application.start/2:
```elixir
# Después de iniciar los hijos:
ElPaso.Plugin.Loader.load_all()
```

---

## 16.23 — Engine.Registry: no tiene start_link adecuado para supervisión

```elixir
# ACTUAL:
def start_link(_opts) do
  GenServer.start_link(__MODULE__, [], name: __MODULE__)
end
# Pero el árbol de Application referencia Engine.Registry así:
ElPaso.Engine.Registry,
# Esto llama start_link([]) sin argumentos — OK si start_link acepta []
```

Verificar que `child_spec` está correcto. `use GenServer` genera el
`child_spec` automáticamente si `start_link/1` acepta un keyword list.
El actual acepta `_opts` — correcto. No hay problema aquí.

---

## 16.24 — Context.Manager usa Config.cluster_mode? que no existe

```elixir
# ACTUAL:
is_cluster = Config.cluster_mode?()   # NO existe — debería ser cluster_enabled?()
```

Corrección:
```elixir
is_cluster = ElPaso.Config.cluster_enabled?()
```

---

## 16.25 — Repo no tiene config en config.exs → Ecto no sabe a qué BD conectar

Aunque `ElPaso.Repo` existe, sin `config :elpaso, ElPaso.Repo, url: ...`
en `config/config.exs`, Ecto lanza `Ecto.InvalidRepoError` al arrancar.

Esto ya está cubierto en la Sección 14 del prompt (config/config.exs).
Verificar que se crea el archivo antes de ejecutar `mix ecto.create`.

---

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CHECKLIST EXHAUSTIVO DE VERIFICACIÓN FINAL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ejecutar en orden. Todos deben pasar antes de dar ElPaso por terminado.

```bash
# COMPILACIÓN
mix compile --warnings-as-errors
# → 0 warnings, 0 errors

# NINGÚN MÓDULO INEXISTENTE REFERENCIADO
grep -rn "ModelDownloaderRegistry\|ElPaso.Context.BuiltPrompt\b\|ElPaso.Context.PrefixBlock\b\|cluster_mode?" lib/
# → 0 resultados

# SIN ATOM INJECTION
grep -rn "String\.to_atom(" lib/ | grep -v "to_existing_atom\|#"
# → 0 resultados

# SIN RAISES EN CONFIG
grep -rn "raise.*CONFIGURACIÓN\|raise.*ENV\b" lib/
# → 0 resultados

# SIN IO.PUTS EN PRODUCCIÓN
grep -rn "IO\.puts\|IO\.inspect" lib/ | grep -v "test\|#\|mix/"
# → 0 resultados

# MIGRACIONES
mix ecto.migrate
# → 5 migraciones aplicadas sin error

# ARRANQUE SIN CONFIG
rm -f ~/.config/elpaso/elpaso.conf && mix run --no-halt &
sleep 3
# → NO hay RuntimeError ni ArgumentError en el log
# → SÍ aparece el banner de "no engines configured"

# ENDPOINTS BÁSICOS
curl -s http://localhost:8081/health | jq .
# → {"status":"ok"}

curl -s http://localhost:8081/v1/models | jq .
# → {"object":"list","data":[]}

curl -s -X POST http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"hi"}]}' | jq .
# → {"error":{"message":"No models available","type":"no_models_available",...}}

# REGISTRO DE ENGINE Y MODELO
mix elpaso.engine.add --alias llama-fast --type local_process \
  --binary /usr/bin/llama-server --port 8081 --gpu-layers 35
# → ✓ Engine 'llama-fast' registered.

mix elpaso.model.add --alias fast --engine llama-fast \
  --path ~/models/fast.gguf --type chat --template llama3
# → ✓ Model 'fast' registered.

# PERSISTE EN DISCO
cat ~/.config/elpaso/elpaso.conf | jq '.engines | keys'
# → ["llama-fast"]

# STORAGE REAL
mix run -e '
  ElPaso.Context.Storage.create_session() |> IO.inspect()
  ElPaso.Context.Storage.get_session("no-existe") |> IO.inspect()
'
# → {:ok, "uuid-real"}
# → {:error, :not_found}

# CONTEXT.MANAGER REGISTRADO Y FUNCIONAL
mix run -e '
  {:ok, sid, _} = ElPaso.Context.Manager.get_or_create_session()
  IO.puts("Session: #{sid}")
'
# → Session: <uuid-real>

# CON MODELO REAL (llama-server arrancado)
curl -s -X POST http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"Di hola"}]}' | jq .
# → {"choices":[{"message":{"role":"assistant","content":"¡Hola!"},...}],"elpaso":{"session_id":"..."}}

# CONTEXTO PERSISTENTE (segunda llamada referencia la primera)
SID=$(curl -s -X POST http://localhost:8081/v1/chat/completions \
  -d '{"model":"auto","messages":[{"role":"user","content":"Mi nombre es Lorenzo"}]}' | jq -r '.elpaso.session_id')

curl -s -X POST http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"auto\",\"elpaso\":{\"session_id\":\"$SID\"},
       \"messages\":[{\"role\":\"user\",\"content\":\"¿Cuál es mi nombre?\"}]}" | jq -r '.choices[0].message.content'
# → "Tu nombre es Lorenzo."

# DASHBOARD FUNCIONAL
curl -s http://localhost:8081/dashboard/api/state | jq '.sessions.active'
# → número entero (no null)

# DOCUMENTACIÓN
mix docs
# → 0 errores, docs generados en doc/

# CREDO
mix credo --strict
# → 0 issues nuevos (o lista acotada de issues preexistentes conocidos)
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 17 — IMPLEMENTACIONES COMPLETAS (sin referencias a otros documentos)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 17.1 — mix.exs completo

Crear `mix.exs` (no existe en el proyecto):

```elixir
if System.otp_release() < "28" do
  raise "ElPaso requiere OTP 28+."
end

defmodule ElPaso.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :elpaso,
      version: @version,
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {ElPaso.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:plug_cowboy, "~> 2.7"},
      {:finch, "~> 0.19"},
      {:jason, "~> 1.4"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, "~> 0.17"},
      {:pgvector, "~> 0.2"},
      {:nimble_options, "~> 1.1"},
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jose, "~> 1.11"},
      {:libcluster, "~> 3.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:mox, "~> 1.1", only: :test},
      {:bypass, "~> 2.1", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
```

---

## 17.2 — Engine.LlamaServer completo

Crear `lib/el_paso/engine/llama_server.ex`:

```elixir
defmodule ElPaso.Engine.LlamaServer do
  @moduledoc """
  Engine adapter for llama-server (llama.cpp). OpenAI-compatible HTTP API.
  """
  @behaviour ElPaso.Engine
  require Logger
  alias ElPaso.Engine.{ChatTemplate, Response, Chunk}

  @impl true
  def name, do: :llama_server

  @impl true
  def type, do: :local_process

  @impl true
  def infer(prompt, params, config) do
    start = System.monotonic_time(:millisecond)
    body  = build_request_body(prompt, params, config, false)
    url   = "#{config[:base_url] || "http://localhost:8081/v1"}/chat/completions"

    case http_post(url, body, config[:api_key]) do
      {:ok, %{status: 200, body: raw}} ->
        case Jason.decode(raw) do
          {:ok, data} ->
            content = get_in(data, ["choices", Access.at(0), "message", "content"]) || ""
            finish  = get_in(data, ["choices", Access.at(0), "finish_reason"]) || "stop"
            usage   = data["usage"] || %{}
            latency = System.monotonic_time(:millisecond) - start
            {:ok, %Response{
              content:           content,
              finish_reason:     String.to_atom(finish),
              prompt_tokens:     usage["prompt_tokens"]     || 0,
              completion_tokens: usage["completion_tokens"] || 0,
              latency_ms:        latency
            }}
          {:error, _} -> {:error, :invalid_json_response}
        end

      {:ok, %{status: 401}} -> {:error, :unauthorized}
      {:ok, %{status: 429}} -> {:error, :rate_limited}
      {:ok, %{status: s}}   -> {:error, {:http_error, s}}
      {:error, r}           -> {:error, {:network_error, r}}
    end
  rescue
    e -> {:error, {:exception, Exception.message(e)}}
  end

  @impl true
  def stream(prompt, params, config, chunk_callback) do
    body = build_request_body(prompt, params, config, true)
    url  = "#{config[:base_url] || "http://localhost:8081/v1"}/chat/completions"

    Finch.build(:post, url, headers(config[:api_key]), Jason.encode!(body))
    |> Finch.stream(ElPasoFinch, fn
      {:status, 200}, acc -> {:cont, acc}
      {:status, c},   _   -> {:halt, {:error, {:http_error, c}}}
      {:headers, _},  acc -> {:cont, acc}
      {:data, data},  acc ->
        parse_sse_chunks(data, chunk_callback)
        {:cont, acc}
    end, [])
    |> case do
      {:ok, _}    -> :ok
      {:error, r} -> {:error, r}
    end
  rescue
    e -> {:error, {:exception, Exception.message(e)}}
  end

  @impl true
  def prepare_prefix(prefix, _config), do: prefix

  @impl true
  def health_check(config) do
    url = (config[:base_url] || "http://localhost:8081/v1")
          |> String.replace("/v1", "")
          |> Kernel.<>("/health")
    case Finch.build(:get, url) |> Finch.request(ElPasoFinch, receive_timeout: 5_000) do
      {:ok, %{status: 200}} -> :ok
      _                     -> {:error, :unavailable}
    end
  rescue
    _ -> {:error, :unavailable}
  end

  @impl true
  def format_messages(messages, context_spec) do
    template = String.to_atom(context_spec[:chat_template] || "chatml")
    ChatTemplate.format(messages, nil, template)
  end

  defp build_request_body(prompt, params, config, stream) do
    template = String.to_atom(config[:chat_template] || "chatml")
    messages  = case ChatTemplate.format(prompt.messages, prompt.system, template) do
      {:passthrough, msgs} -> msgs
      {:formatted, text}   -> [%{"role" => "user", "content" => text}]
    end
    %{
      model:       config[:model_name] || "local",
      messages:    messages,
      stream:      stream,
      temperature: params[:temperature] || params["temperature"] || 0.7,
      max_tokens:  params[:max_tokens]  || params["max_tokens"]  || 1024
    }
  end

  defp http_post(url, body, api_key) do
    case Finch.build(:post, url, headers(api_key), Jason.encode!(body))
         |> Finch.request(ElPasoFinch, receive_timeout: 120_000) do
      {:ok, resp} -> {:ok, %{status: resp.status, body: resp.body}}
      {:error, r} -> {:error, r}
    end
  end

  defp headers(api_key) do
    [
      {"content-type", "application/json"},
      {"authorization", "Bearer #{api_key || "sk-local"}"}
    ]
  end

  defp parse_sse_chunks(data, callback) do
    data
    |> String.split("\n", trim: true)
    |> Enum.each(fn
      "data: [DONE]" ->
        callback.(%Chunk{content: "", done: true, tokens: nil})
      "data: " <> json ->
        case Jason.decode(json) do
          {:ok, chunk} ->
            content = get_in(chunk, ["choices", Access.at(0), "delta", "content"]) || ""
            if content != "", do: callback.(%Chunk{content: content, done: false, tokens: nil})
          _ -> :ok
        end
      _ -> :ok
    end)
  end
end
```

---

## 17.3 — Engine.OpenAI completo

Crear `lib/el_paso/engine/openai.ex`:

```elixir
defmodule ElPaso.Engine.OpenAI do
  @moduledoc """
  Engine adapter for OpenAI-compatible APIs (remote or local).
  Delegates to LlamaServer since the protocol is identical.
  """
  @behaviour ElPaso.Engine

  defdelegate name(),                              to: __MODULE__, as: :_name
  defdelegate type(),                              to: __MODULE__, as: :_type
  defdelegate infer(prompt, params, config),       to: ElPaso.Engine.LlamaServer
  defdelegate stream(prompt, params, config, cb),  to: ElPaso.Engine.LlamaServer
  defdelegate prepare_prefix(prefix, config),      to: ElPaso.Engine.LlamaServer
  defdelegate format_messages(messages, ctx),      to: ElPaso.Engine.LlamaServer

  @impl true
  def name, do: :openai

  @impl true
  def type, do: :remote_api

  @impl true
  def health_check(config) do
    url = "#{config[:base_url] || "https://api.openai.com/v1"}/models"
    case Finch.build(:get, url, [{"authorization", "Bearer #{config[:api_key]}"}])
         |> Finch.request(ElPasoFinch, receive_timeout: 5_000) do
      {:ok, %{status: 200}} -> :ok
      _                     -> {:error, :unavailable}
    end
  rescue
    _ -> {:error, :unavailable}
  end
end
```

---

## 17.4 — Context.Storage: reemplazar stubs por Ecto real

Reemplazar `lib/el_paso/context/storage.ex` completamente:

```elixir
defmodule ElPaso.Context.Storage do
  @moduledoc """
  Data access layer for ElPaso context persistence.

  All operations go through Ecto/PostgreSQL. No business logic here.
  """

  import Ecto.Query
  require Logger

  alias ElPaso.Repo
  alias ElPaso.Context.Schemas.{Session, Message, ConversationSummary, RoutingDecision}

  # ── Sessions ────────────────────────────────────────────────────────────────

  def create_session(opts \\ []) do
    attrs = %{
      context_mode: Keyword.get(opts, :context_mode, :transparent),
      user_id:      Keyword.get(opts, :user_id),
      metadata:     Keyword.get(opts, :metadata, %{})
    }
    case Repo.insert(Session.changeset(%Session{}, attrs)) do
      {:ok, session}   -> {:ok, session.id}
      {:error, cs}     -> {:error, {:changeset, cs}}
    end
  rescue
    e -> repo_error("create_session", e)
  end

  def get_session(session_id) do
    case Repo.get(Session, session_id) do
      nil     -> {:error, :not_found}
      session -> {:ok, session}
    end
  rescue
    e -> repo_error("get_session", e)
  end

  def touch_session(session_id) do
    {count, _} = Repo.update_all(
      from(s in Session, where: s.id == ^session_id),
      set: [last_active_at: DateTime.utc_now()]
    )
    if count > 0, do: :ok, else: {:error, :not_found}
  rescue
    e -> repo_error("touch_session", e)
  end

  def delete_session(session_id) do
    case Repo.get(Session, session_id) do
      nil     -> {:error, :not_found}
      session -> Repo.delete!(session); :ok
    end
  rescue
    e -> repo_error("delete_session", e)
  end

  def list_sessions do
    Repo.all(Session)
  rescue
    _ -> []
  end

  def list_users do
    Repo.all(from s in Session, select: s.user_id, distinct: true)
    |> Enum.reject(&is_nil/1)
  rescue
    _ -> []
  end

  # ── Messages ─────────────────────────────────────────────────────────────────

  def save_message(session_id, role, content, opts \\ []) do
    last_seq = Repo.one(
      from m in Message,
      where: m.session_id == ^session_id,
      select: max(m.sequence_number)
    ) || 0

    attrs = %{
      session_id:      session_id,
      sequence_number: last_seq + 1,
      role:            role,
      content:         content,
      token_estimate:  Keyword.get(opts, :token_estimate, estimate_tokens(content)),
      model_id:        Keyword.get(opts, :model_id)
    }

    case Repo.insert(Message.changeset(%Message{}, attrs)) do
      {:ok, msg}   -> {:ok, msg.id}
      {:error, cs} -> {:error, {:changeset, cs}}
    end
  rescue
    e -> repo_error("save_message", e)
  end

  def get_window(session_id, limit) do
    msgs = Repo.all(
      from m in Message,
      where: m.session_id == ^session_id and is_nil(m.archived_at),
      order_by: [asc: m.sequence_number],
      limit: ^limit
    )
    {:ok, msgs}
  rescue
    e -> repo_error("get_window", e)
  end

  def get_all_messages(session_id) do
    msgs = Repo.all(
      from m in Message,
      where: m.session_id == ^session_id,
      order_by: [asc: m.sequence_number]
    )
    {:ok, msgs}
  rescue
    e -> repo_error("get_all_messages", e)
  end

  def archive_messages_before(session_id, last_message_id) do
    {count, _} = Repo.update_all(
      from(m in Message,
        where: m.session_id == ^session_id
          and m.id <= ^last_message_id
          and is_nil(m.archived_at)),
      set: [archived_at: DateTime.utc_now()]
    )
    {:ok, count}
  rescue
    e -> repo_error("archive_messages_before", e)
  end

  # ── Summaries ────────────────────────────────────────────────────────────────

  def get_latest_summary(session_id) do
    case Repo.one(
           from s in ConversationSummary,
           where: s.session_id == ^session_id and is_nil(s.archived_at),
           order_by: [desc: s.generated_at],
           limit: 1) do
      nil     -> {:error, :not_found}
      summary -> {:ok, summary}
    end
  rescue
    e -> repo_error("get_latest_summary", e)
  end

  def save_summary(session_id, content, opts \\ []) do
    attrs = %{
      session_id:               session_id,
      content:                  content,
      covers_until_message_id:  Keyword.get(opts, :covers_until_message_id),
      token_estimate:           Keyword.get(opts, :token_estimate, estimate_tokens(content)),
      generated_by_model:       Keyword.get(opts, :generated_by_model, "unknown"),
      generated_at:             DateTime.utc_now()
    }
    case Repo.insert(ConversationSummary.changeset(%ConversationSummary{}, attrs)) do
      {:ok, s}     -> {:ok, s}
      {:error, cs} -> {:error, {:changeset, cs}}
    end
  rescue
    e -> repo_error("save_summary", e)
  end

  # ── Routing decisions ─────────────────────────────────────────────────────────

  def save_routing_decision(decision) do
    attrs = %{
      request_id:          decision.request_id,
      session_id:          decision.session_id,
      selected_model:      decision.selected_model,
      runner_up:           decision.runner_up,
      task_type:           to_string(decision.features.task_type),
      complexity_score:    decision.features.complexity_score,
      token_estimate:      decision.features.token_estimate,
      feature_vector:      safe_map(decision.features),
      scores:              decision.scores || %{},
      reason:              decision.reason,
      decision_latency_us: decision.decision_latency_us,
      decided_at:          decision.decided_at
    }
    case Repo.insert(RoutingDecision.changeset(%RoutingDecision{}, attrs)) do
      {:ok, _}     -> :ok
      {:error, cs} -> {:error, {:changeset, cs}}
    end
  rescue
    e -> repo_error("save_routing_decision", e)
  end

  def update_routing_outcome(request_id, outcome, latency_ms) do
    case Repo.get(RoutingDecision, request_id) do
      nil -> {:error, :not_found}
      rd  ->
        Repo.update!(RoutingDecision.changeset(rd,
          %{outcome: to_string(outcome), latency_ms: latency_ms}))
        :ok
    end
  rescue
    e -> repo_error("update_routing_outcome", e)
  end

  def query_routing_decisions(opts \\ []) do
    since        = Keyword.get(opts, :since, DateTime.add(DateTime.utc_now(), -86_400))
    with_outcome = Keyword.get(opts, :with_outcome, false)

    query = from rd in RoutingDecision, where: rd.decided_at >= ^since
    query = if with_outcome, do: where(query, [rd], not is_nil(rd.outcome)), else: query

    Repo.all(query)
  rescue
    _ -> []
  end

  # ── Auto-tune ─────────────────────────────────────────────────────────────────

  def save_auto_tune_run(run) do
    # Persist to auto_tune_runs table (migration in Section 3.2)
    Repo.insert_all("auto_tune_runs", [%{
      applied_changes: run[:applied] || 0,
      changes_json:    Jason.encode!(run[:changes] || []),
      ran_at:          DateTime.utc_now()
    }])
    :ok
  rescue
    _ -> :ok
  end

  def query_auto_tune_runs(_opts \\ %{}) do
    Repo.all(from r in "auto_tune_runs",
      order_by: [desc: r.ran_at], limit: 10,
      select: %{ran_at: r.ran_at, applied_changes: r.applied_changes})
  rescue
    _ -> []
  end

  def get_last_auto_tune_run do
    Repo.one(from r in "auto_tune_runs",
      order_by: [desc: r.ran_at], limit: 1,
      select: %{ran_at: r.ran_at, changes_json: r.changes_json})
  rescue
    _ -> nil
  end

  # ── Stubs for future features ─────────────────────────────────────────────────

  def get_model_pricing(_model_id),      do: {:error, :not_found}
  def upsert_api_usage(_usage),          do: :ok
  def daily_spend(_user_id),             do: 0.0
  def usage_report(_opts),               do: %{users: [], total_cost: 0.0}
  def usage_report_csv(_opts),           do: "user,model,cost\n"

  # ── Private ───────────────────────────────────────────────────────────────────

  defp estimate_tokens(content), do: max(div(String.length(content || ""), 3), 1)

  defp safe_map(struct) when is_struct(struct) do
    struct |> Map.from_struct() |> Jason.encode!() |> Jason.decode!()
  rescue
    _ -> %{}
  end
  defp safe_map(map) when is_map(map), do: map
  defp safe_map(_), do: %{}

  defp repo_error(fn_name, exception) do
    Logger.error("[Storage.#{fn_name}] #{Exception.message(exception)}")
    {:error, :db_error}
  end
end
```

---

## 17.5 — Domain.ModelState, ModelWorker, ModelSupervisor, ModelManager

### ModelState — crear `lib/el_paso/domain/model_state.ex`:

```elixir
defmodule ElPaso.Domain.ModelState do
  @moduledoc "Runtime state of a registered model."

  defstruct [
    :model_id,
    status:                   :cold,
    pid:                      nil,
    current_queue_depth:      0,
    avg_latency_ms:           0,
    p95_latency_ms:           0,
    last_error_at:            nil,
    last_error_reason:        nil,
    consecutive_errors:       0,
    restart_count:            0,
    ram_mb:                   0,
    vram_mb:                  0,
    started_at:               nil,
    last_call_at:             nil,
    node:                     nil,
    routing_config:           %{},
    complexity_ceiling:       1.0,
    cold_start_estimate_ms:   10_000
  ]

  @type t :: %__MODULE__{}
end
```

### ModelWorker — crear `lib/el_paso/domain/model_worker.ex`:

```elixir
defmodule ElPaso.Domain.ModelWorker do
  @moduledoc "Manages the lifecycle of a single model: start, health-check, idle-stop."
  use GenServer, restart: :permanent
  require Logger

  alias ElPaso.Config.Merger
  alias ElPaso.Domain.ModelState

  @health_interval_ms 30_000
  @idle_interval_ms   60_000

  # ── API ──────────────────────────────────────────────────────────────────────

  def start_link(model_config) do
    GenServer.start_link(__MODULE__, model_config,
      name: via(model_config[:alias] || model_config[:id] || model_config.alias))
  end

  def ensure_hot(model_alias, timeout_ms \\ 30_000) do
    GenServer.call(via(model_alias), {:ensure_hot, timeout_ms}, timeout_ms + 2_000)
  rescue
    _ -> {:error, :worker_unavailable}
  end

  def stop_model(model_alias) do
    GenServer.call(via(model_alias), :stop_model)
  rescue
    _ -> :ok
  end

  def get_state(model_alias) do
    GenServer.call(via(model_alias), :get_state)
  rescue
    _ -> {:error, :worker_unavailable}
  end

  def record_call_result(model_alias, latency_ms, outcome) do
    GenServer.cast(via(model_alias), {:record_call, latency_ms, outcome})
  rescue
    _ -> :ok
  end

  # ── Callbacks ─────────────────────────────────────────────────────────────────

  @impl true
  def init(model_config) do
    alias_key = model_config[:alias] || model_config[:id]
    state = %ModelState{
      model_id:               alias_key,
      status:                 :cold,
      routing_config:         model_config[:routing] || %{},
      complexity_ceiling:     get_in(model_config, [:routing, :complexity_ceiling]) || 1.0,
      cold_start_estimate_ms: get_in(model_config, [:routing, :cold_start_estimate_ms]) || 10_000
    }

    Process.send_after(self(), :health_check, @health_interval_ms)
    Process.send_after(self(), :idle_check,   @idle_interval_ms)

    if get_in(model_config, [:lifecycle, :autostart]) do
      Process.send_after(self(), :autostart, 500)
    end

    {:ok, %{config: model_config, model_state: state, waiters: [], latencies: []}}
  end

  @impl true
  def handle_call({:ensure_hot, _timeout}, _from, %{model_state: %{status: :hot}} = state) do
    {:reply, :ok, state}
  end

  def handle_call({:ensure_hot, _timeout}, _from, %{model_state: %{status: :error}} = state) do
    {:reply, {:error, :model_error}, state}
  end

  def handle_call({:ensure_hot, timeout_ms}, from, state) do
    new_state = if state.model_state.status == :cold, do: start_engine(state), else: state
    waiters   = [{from, timeout_ms, System.monotonic_time(:millisecond)} | new_state.waiters]
    {:noreply, %{new_state | waiters: waiters}}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state.model_state}, state}
  end

  def handle_call(:stop_model, _from, state) do
    {:reply, :ok, stop_engine(state)}
  end

  @impl true
  def handle_cast({:record_call, latency_ms, outcome}, state) do
    ms    = state.model_state
    alpha = 0.1
    new_avg = round(ms.avg_latency_ms * (1 - alpha) + latency_ms * alpha)
    latencies = Enum.take([latency_ms | state.latencies], 50)
    p95 = percentile_95(latencies)

    {new_errors, new_error_at} =
      if outcome == :success, do: {0, ms.last_error_at},
      else: {ms.consecutive_errors + 1, DateTime.utc_now()}

    new_ms = %{ms |
      avg_latency_ms:     new_avg,
      p95_latency_ms:     p95,
      consecutive_errors: new_errors,
      last_error_at:      new_error_at,
      last_call_at:       DateTime.utc_now()
    }
    {:noreply, %{state | model_state: new_ms, latencies: latencies}}
  end

  @impl true
  def handle_info(:autostart, state),     do: {:noreply, start_engine(state)}
  def handle_info(:health_check, state) do
    Process.send_after(self(), :health_check, @health_interval_ms)
    {:noreply, perform_health_check(state)}
  end
  def handle_info(:idle_check, state) do
    Process.send_after(self(), :idle_check, @idle_interval_ms)
    {:noreply, maybe_stop_idle(state)}
  end
  def handle_info({:engine_started, _port}, state) do
    Logger.info("[ModelWorker #{state.model_state.model_id}] Engine started")
    new_ms   = %{state.model_state | status: :hot, started_at: DateTime.utc_now()}
    new_state = %{state | model_state: new_ms}
    notify_waiters(new_state, :ok)
    {:noreply, %{new_state | waiters: []}}
  end
  def handle_info({:engine_failed, reason}, state) do
    Logger.error("[ModelWorker #{state.model_state.model_id}] Start failed: #{inspect(reason)}")
    new_ms   = %{state.model_state |
      status:             :error,
      last_error_at:      DateTime.utc_now(),
      last_error_reason:  inspect(reason),
      consecutive_errors: state.model_state.consecutive_errors + 1
    }
    new_state = %{state | model_state: new_ms}
    notify_waiters(new_state, {:error, reason})
    {:noreply, %{new_state | waiters: []}}
  end
  def handle_info(_, state), do: {:noreply, state}

  # ── Private ───────────────────────────────────────────────────────────────────

  defp via(model_alias) do
    {:via, Registry, {ElPaso.Domain.ModelRegistry, model_alias}}
  end

  defp start_engine(%{model_state: %{status: s}} = state) when s not in [:cold] do
    state
  end
  defp start_engine(state) do
    if get_in(state.config, [:source, :type]) == "remote_model" do
      %{state | model_state: %{state.model_state | status: :hot}}
    else
      parent = self()
      Task.start(fn -> launch_process(parent, state.config) end)
      %{state | model_state: %{state.model_state | status: :warming}}
    end
  end

  defp launch_process(parent, model_config) do
    engine_alias  = model_config[:engine]
    global_config = ElPaso.Config.Loader.get()
    engine_config = Map.get(global_config.engines || %{}, engine_alias) || %{}

    base_args   = engine_config[:base_args] || %{}
    model_args  = model_config[:engine_args] || %{}
    merged_args = Merger.merge(base_args, model_args)

    binary = engine_config[:binary] || "llama-server"
    model_path = Path.expand(get_in(model_config, [:path]) || "")

    final_args = merged_args ++ if(model_path != "", do: ["--model", model_path], else: [])

    Logger.info("[ModelWorker] Launching: #{binary} #{Enum.join(final_args, " ")}")

    port_str = find_arg(merged_args, "--port") || "8081"
    port_num = String.to_integer(port_str)

    case System.cmd(binary, final_args, stderr_to_stdout: false, into: "") do
      {_, 0} -> send(parent, {:engine_started, port_num})
      {out, code} -> send(parent, {:engine_failed, "exit #{code}: #{String.slice(out, 0, 200)}"})
    end
  rescue
    e -> send(parent, {:engine_failed, Exception.message(e)})
  end

  defp perform_health_check(state) do
    if state.model_state.status == :hot do
      engine_alias  = state.config[:engine]
      global_config = ElPaso.Config.Loader.get()
      engine_config = Map.get(global_config.engines || %{}, engine_alias) || %{}
      port = find_arg(Merger.merge(engine_config[:base_args] || %{},
                                   state.config[:engine_args] || %{}), "--port") || "8081"
      url  = "http://localhost:#{port}/health"

      case Finch.build(:get, url) |> Finch.request(ElPasoFinch, receive_timeout: 5_000) do
        {:ok, %{status: 200}} -> state
        _ ->
          Logger.warning("[ModelWorker #{state.model_state.model_id}] Health check failed")
          %{state | model_state: %{state.model_state | status: :error,
                                   last_error_at: DateTime.utc_now()}}
      end
    else
      state
    end
  rescue
    _ -> state
  end

  defp maybe_stop_idle(state) do
    max_idle = get_in(state.config, [:lifecycle, :max_idle_minutes])
    last     = state.model_state.last_call_at

    if max_idle && last && state.model_state.status == :hot do
      idle_ms = DateTime.diff(DateTime.utc_now(), last, :millisecond)
      if idle_ms > max_idle * 60_000 do
        Logger.info("[ModelWorker #{state.model_state.model_id}] Stopping idle model")
        stop_engine(state)
      else
        state
      end
    else
      state
    end
  end

  defp stop_engine(state) do
    %{state | model_state: %{state.model_state | status: :cold, pid: nil}}
  end

  defp notify_waiters(state, result) do
    now = System.monotonic_time(:millisecond)
    Enum.each(state.waiters, fn {from, timeout_ms, queued_at} ->
      reply = if now - queued_at < timeout_ms, do: result, else: {:error, :timeout}
      GenServer.reply(from, reply)
    end)
  end

  defp find_arg(args, key) when is_list(args) do
    idx = Enum.find_index(args, &(&1 == key))
    if idx, do: Enum.at(args, idx + 1), else: nil
  end
  defp find_arg(args, key) when is_map(args) do
    Map.get(args, key) || Map.get(args, String.to_atom(key))
  end
  defp find_arg(_, _), do: nil

  defp percentile_95([]), do: 0
  defp percentile_95(ls) do
    sorted = Enum.sort(ls)
    Enum.at(sorted, max(round(length(sorted) * 0.95) - 1, 0))
  end
end
```

### ModelSupervisor — reemplazar `lib/el_paso/domain/model_supervisor.ex`:

```elixir
defmodule ElPaso.Domain.ModelSupervisor do
  @moduledoc "Supervisor for model lifecycle management."
  use Supervisor

  def start_link(args \\ []) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl Supervisor
  def init(_args) do
    children = [
      {Registry, keys: :unique, name: ElPaso.Domain.ModelRegistry},
      {DynamicSupervisor, name: ElPaso.Domain.ModelPool, strategy: :one_for_one}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### ModelManager — reemplazar `lib/el_paso/domain/model_manager.ex`:

```elixir
defmodule ElPaso.Domain.ModelManager do
  @moduledoc "Facade for model lifecycle management."
  require Logger

  def start_configured_models do
    ElPaso.Config.Loader.list_models()
    |> Enum.filter(&(&1[:enabled] != false))
    |> Enum.each(&start_model/1)
  end

  def start_model(model_config) do
    case DynamicSupervisor.start_child(
           ElPaso.Domain.ModelPool,
           {ElPaso.Domain.ModelWorker, model_config}) do
      {:ok, _}                       -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason}               ->
        Logger.error("[ModelManager] Cannot start #{model_config[:alias]}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def ensure_hot(model_alias, timeout_ms \\ 30_000) do
    case Registry.lookup(ElPaso.Domain.ModelRegistry, model_alias) do
      [] -> {:error, :model_not_registered}
      _  -> ElPaso.Domain.ModelWorker.ensure_hot(model_alias, timeout_ms)
    end
  end

  def stop(model_alias) do
    ElPaso.Domain.ModelWorker.stop_model(model_alias)
  end

  def state(model_alias) do
    ElPaso.Domain.ModelWorker.get_state(model_alias)
  end

  def all_states do
    Registry.select(ElPaso.Domain.ModelRegistry,
      [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.flat_map(fn model_alias ->
      case ElPaso.Domain.ModelWorker.get_state(model_alias) do
        {:ok, s} -> [s]
        _        -> []
      end
    end)
  end

  def record_call_result(model_alias, latency_ms, outcome) do
    ElPaso.Domain.ModelWorker.record_call_result(model_alias, latency_ms, outcome)
  end

  # Called after Application.start/2 to warm up autostart models
  def boot_autostart_models do
    ElPaso.Config.Loader.list_models()
    |> Enum.filter(&get_in(&1, [:lifecycle, :autostart]))
    |> Enum.each(fn model ->
      Task.start(fn ->
        ElPaso.Domain.ModelManager.ensure_hot(model[:alias], 60_000)
      end)
    end)
  end
end
```

---

## 17.6 — Context.Manager: añadir funciones faltantes y corregir start_link

Editar `lib/el_paso/context/manager.ex`:

```elixir
# CAMBIO 1: añadir name: en start_link
def start_link(args) do
  GenServer.start_link(__MODULE__, args, name: __MODULE__)
end

# CAMBIO 2: get_or_create_session debe ser serializado
def get_or_create_session(session_id \\ nil, user_id \\ nil) do
  GenServer.call(__MODULE__, {:get_or_create, session_id, user_id}, 10_000)
end

# CAMBIO 3: añadir handle_call correspondiente
@impl true
def handle_call({:get_or_create, session_id, user_id}, _from, state) do
  result = do_get_or_create(session_id, user_id)
  {:reply, result, state}
end

defp do_get_or_create(session_id, user_id) do
  final_id = maybe_prefix_session_id(session_id, user_id)

  case get_session_state(final_id) do
    {:ok, session_state} ->
      {:ok, final_id, session_state}
    {:error, :not_found} ->
      case ElPaso.Context.Storage.create_session(user_id: user_id) do
        {:ok, new_id} ->
          session_state = %SessionState{
            session_id:                  new_id,
            context_mode:                "transparent",
            window:                      [],
            window_token_count:          0,
            summarization_in_progress:   false,
            semantic_retrieval_enabled:  false,
            created_at:                  DateTime.utc_now(),
            last_active_at:              DateTime.utc_now()
          }
          :ets.insert(:session_states,
            {new_id, session_state, System.monotonic_time(:millisecond)})
          {:ok, new_id, session_state}
        {:error, _} = err -> err
      end
  end
end

# CAMBIO 4: reload_session real
def reload_session(session_id) do
  case ElPaso.Context.Storage.get_session(session_id) do
    {:ok, session} ->
      session_state = %SessionState{
        session_id:                  session_id,
        context_mode:                to_string(session.context_mode || "transparent"),
        window:                      [],
        window_token_count:          0,
        summarization_in_progress:   false,
        semantic_retrieval_enabled:  false,
        created_at:                  session.created_at,
        last_active_at:              session.last_active_at
      }
      :ets.insert(:session_states,
        {session_id, session_state, System.monotonic_time(:millisecond)})
      {:ok, session_state}

    {:error, :not_found} = err -> err
    {:error, _}                -> {:error, :not_found}
  end
end

# CAMBIO 5: append_turn
def append_turn(session_id, user_message, assistant_response, model_id) do
  with {:ok, _} <- ElPaso.Context.Storage.save_message(
                     session_id, "user", user_message),
       {:ok, _} <- ElPaso.Context.Storage.save_message(
                     session_id, "assistant", assistant_response,
                     model_id: model_id) do
    update_window_ets(session_id, user_message, assistant_response, model_id)
    maybe_trigger_summary(session_id)
    :ok
  end
end

defp update_window_ets(session_id, user_msg, assistant_msg, model_id) do
  case get_session_state(session_id) do
    {:ok, state} ->
      cfg = ElPaso.Config.Loader.get()
      window_size = get_in(cfg, [:session_defaults, :window_size]) || 10
      new_msgs = [
        %{role: "user",      content: user_msg},
        %{role: "assistant", content: assistant_msg, model_id: model_id}
      ]
      window = ((state.window || []) ++ new_msgs) |> Enum.take(-(window_size * 2))
      tokens = Enum.sum(Enum.map(window, &div(String.length(&1[:content] || ""), 3)))
      update_session_state(session_id, %{state |
        window:             window,
        window_token_count: tokens,
        last_model_id:      model_id,
        last_active_at:     DateTime.utc_now()
      })
    _ -> :ok
  end
end

defp maybe_trigger_summary(session_id) do
  case get_session_state(session_id) do
    {:ok, %{summarization_in_progress: false} = state} ->
      cfg         = ElPaso.Config.Loader.get()
      trigger_pct = get_in(cfg, [:session_defaults, :summary_trigger_pct]) || 0.8
      budget      = 4096
      if state.window_token_count > budget * trigger_pct do
        ElPaso.Context.SummarizationWorker.trigger_async(
          session_id, state.window, nil)
      end
    _ -> :ok
  end
end

# CAMBIO 6: get_context_layers
def get_context_layers(session_id, _context_spec) do
  case get_session_state(session_id) do
    {:ok, state} ->
      summary = case ElPaso.Context.Storage.get_latest_summary(session_id) do
        {:ok, s} -> s.content
        _        -> nil
      end
      {:ok, %{summary: summary, window: state.window || [], semantic: []}}
    {:error, _} = err -> err
  end
end

# CAMBIO 7: flags de summarization
def set_summarization_flag(session_id, flag) do
  case get_session_state(session_id) do
    {:ok, state} -> update_session_state(session_id, %{state | summarization_in_progress: flag})
    _            -> :ok
  end
end

def on_summary_complete(session_id, _summary) do
  set_summarization_flag(session_id, false)
end

# CAMBIO 8: fix cluster_mode? → cluster_enabled?
# En get_session_state, reemplazar:
# is_cluster = Config.cluster_mode?()
# por:
# is_cluster = ElPaso.Config.cluster_enabled?()

# CAMBIO 9: fix auth_enabled? en maybe_prefix_session_id
defp auth_enabled? do
  ElPaso.Config.auth_enabled?()
end
# Y en ambas cláusulas de maybe_prefix_session_id, reemplazar
# Map.get(ElPaso.Config.Loader.get(), :auth, %{}) |> Map.get(:enabled, false)
# por: auth_enabled?()
```

---

## 17.7 — HTTP.Server: añadir endpoints faltantes

Editar `lib/el_paso/http/server.ex`. Añadir ANTES de `get "/dashboard"`:

```elixir
# ── Basic endpoints ────────────────────────────────────────────────────────────

get "/health" do
  conn
  |> put_resp_content_type("application/json")
  |> send_resp(200, ~s({"status":"ok","version":"1.0.0"}))
end

get "/v1/models" do
  models = ElPaso.Domain.ModelManager.all_states()
  |> Enum.map(fn state ->
    %{
      "id"       => state.model_id,
      "object"   => "model",
      "owned_by" => "elpaso",
      "elpaso"   => %{
        "status"       => Atom.to_string(state.status),
        "queue_depth"  => state.current_queue_depth,
        "avg_latency_ms" => state.avg_latency_ms
      }
    }
  end)

  conn
  |> put_resp_content_type("application/json")
  |> send_resp(200, Jason.encode!(%{"object" => "list", "data" => models}))
end

post "/v1/chat/completions" do
  with {:ok, body, conn}     <- read_body(conn),
       {:ok, params}         <- Jason.decode(body),
       {:ok, chat_request}   <- parse_chat_request(params) do

    user_id    = conn.assigns[:current_user_id] || "anonymous"
    session_id = chat_request[:session_id] ||
                 get_in(params, ["elpaso", "session_id"]) ||
                 params["user"] ||
                 gen_id()
    request_id = gen_id()

    with {:ok, sid, _state} <- ElPaso.Context.Manager.get_or_create_session(
                                 session_id, user_id),
         {:ok, model_id, decision} <- ElPaso.Domain.Router.route(
                                        request_id, sid,
                                        last_user_message(chat_request[:messages]),
                                        chat_request[:overrides] || %{}),
         :ok                    <- ElPaso.Domain.ModelManager.ensure_hot(model_id, 30_000),
         {:ok, model_config}    <- ElPaso.Config.Loader.get_model(model_id),
         {:ok, built_prompt}    <- ElPaso.Context.Builder.build(
                                     sid,
                                     last_user_message(chat_request[:messages]),
                                     build_ctx_spec(model_config)) do

      inference_params = %{}
      |> maybe_put(:temperature, chat_request[:temperature])
      |> maybe_put(:max_tokens,  chat_request[:max_tokens])

      start = System.monotonic_time(:millisecond)

      if chat_request[:stream] do
        handle_streaming(conn, model_id, built_prompt, inference_params,
                         sid, decision, request_id)
      else
        handle_sync(conn, model_id, built_prompt, inference_params,
                    sid, decision, request_id, start)
      end
    else
      {:error, :no_models_available} ->
        json_error(conn, 503, "no_models_available", "No models available")
      {:error, :timeout} ->
        json_error(conn, 504, "model_timeout", "Timeout waiting for model")
      {:error, reason} ->
        json_error(conn, 500, "internal_error", "Error: #{inspect(reason)}")
    end
  else
    {:error, :invalid_json} ->
      json_error(conn, 422, "invalid_request", "Invalid JSON")
    {:error, reason} ->
      json_error(conn, 422, "invalid_request", "Bad request: #{inspect(reason)}")
  end
end

# ── HTTP.Server private helpers ───────────────────────────────────────────────

defp handle_sync(conn, model_id, built_prompt, params, sid, decision, request_id, start) do
  case ElPaso.Engine.Dispatcher.infer(model_id, built_prompt, params) do
    {:ok, response} ->
      latency = System.monotonic_time(:millisecond) - start
      ElPaso.Context.Manager.append_turn(
        sid,
        last_user_message(built_prompt.messages),
        response.content,
        model_id
      )
      ElPaso.Domain.Router.record_outcome(request_id, :success, latency)
      :telemetry.execute([:elpaso, :inference, :complete],
        %{latency_ms: latency,
          prompt_tokens: response.prompt_tokens,
          completion_tokens: response.completion_tokens,
          total_tokens: response.prompt_tokens + response.completion_tokens},
        %{request_id: request_id, session_id: sid, model_id: model_id, streamed: false})

      body = Jason.encode!(%{
        "id"      => "chatcmpl-#{request_id}",
        "object"  => "chat.completion",
        "created" => System.os_time(:second),
        "model"   => model_id,
        "choices" => [%{
          "index"         => 0,
          "message"       => %{"role" => "assistant", "content" => response.content},
          "finish_reason" => Atom.to_string(response.finish_reason)
        }],
        "usage"   => %{
          "prompt_tokens"     => response.prompt_tokens,
          "completion_tokens" => response.completion_tokens,
          "total_tokens"      => response.prompt_tokens + response.completion_tokens
        },
        "elpaso"  => %{
          "session_id"       => sid,
          "routing_decision" => decision.reason,
          "model_id"         => model_id
        }
      })
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, body)

    {:error, reason} ->
      json_error(conn, 502, "model_error", "Engine error: #{inspect(reason)}")
  end
end

defp handle_streaming(conn, model_id, built_prompt, params, sid, decision, request_id) do
  completion_id = "chatcmpl-#{request_id}"
  conn =
    conn
    |> put_resp_content_type("text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("x-accel-buffering", "no")
    |> send_chunked(200)

  first = Jason.encode!(%{
    "id"      => completion_id, "object" => "chat.completion.chunk",
    "choices" => [%{"delta" => %{"role" => "assistant"}, "index" => 0}],
    "elpaso"  => %{"session_id" => sid, "routing_decision" => decision.reason}
  })
  chunk(conn, "data: #{first}\n\n")

  full_content = ""

  full_content =
    case ElPaso.Engine.Dispatcher.stream(model_id, built_prompt, params, fn c ->
           data = Jason.encode!(%{
             "id"      => completion_id,
             "object"  => "chat.completion.chunk",
             "choices" => [%{
               "delta"        => %{"content" => c.content},
               "index"        => 0,
               "finish_reason" => if(c.done, do: "stop", else: nil)
             }]
           })
           chunk(conn, "data: #{data}\n\n")
         end) do
      :ok -> full_content
      _   -> full_content
    end

  chunk(conn, "data: [DONE]\n\n")
  conn
end

defp parse_chat_request(params) do
  overrides = extract_overrides(params)
  {:ok, %{
    messages:    params["messages"] || [],
    model:       params["model"] || "auto",
    stream:      params["stream"] == true,
    temperature: params["temperature"],
    max_tokens:  params["max_tokens"],
    session_id:  overrides[:session_id],
    overrides:   overrides
  }}
end

defp extract_overrides(params) do
  ep = params["elpaso"] || %{}
  %{
    session_id:           ep["session_id"],
    context_mode:         ep["context_mode"],
    window_size:          ep["window_size"],
    force_model:          ep["force_model"],
    latency_tolerance_ms: ep["latency_tolerance_ms"],
    summarize_with_model: ep["summarize_with_model"]
  }
end

defp last_user_message(messages) when is_list(messages) do
  messages
  |> Enum.filter(&(Map.get(&1, "role") == "user" or Map.get(&1, :role) == "user"))
  |> List.last()
  |> case do
    nil -> ""
    m   -> Map.get(m, "content", Map.get(m, :content, ""))
  end
end

defp last_user_message(_), do: ""

defp build_ctx_spec(model_config) do
  ctx = model_config[:context_spec] || %{}
  max = ctx[:max_context_tokens] || 8192
  out = ctx[:reserved_output_tokens] || 1024
  %{
    model_id:               model_config[:alias],
    max_tokens:             max,
    reserved_for_output:    out,
    usable_tokens:          max - out,
    supports_system_prompt: ctx[:supports_system_prompt] != false,
    chat_template:          ctx[:chat_template] || "chatml"
  }
end

defp maybe_put(map, _key, nil),   do: map
defp maybe_put(map, key, value),  do: Map.put(map, key, value)

defp json_error(conn, status, type, message) do
  conn
  |> put_resp_content_type("application/json")
  |> send_resp(status, Jason.encode!(%{
       "error" => %{"message" => message, "type" => type, "code" => "elpaso_#{status}"}
     }))
end

defp gen_id do
  :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end
```

Eliminar también de HTTP.Server el `def start_link/1` que crea un segundo servidor.

---

## 17.8 — Fixes menores: módulos con problemas específicos

### OutputCache: añadir name: en start_link

```elixir
# En lib/el_paso/domain/output_cache.ex:
def start_link(args) do
  GenServer.start_link(__MODULE__, args, name: __MODULE__)
end

# get/2 y put/3 pasan a usar __MODULE__ en lugar de pid:
def get(key) do
  GenServer.call(__MODULE__, {:get, key})
rescue
  _ -> nil
end

def put(key, value) do
  GenServer.cast(__MODULE__, {:put, key, value})
end
```

### PrefixManager: añadir name: en start_link

```elixir
# En lib/el_paso/context/prefix_manager.ex:
def start_link(args) do
  GenServer.start_link(__MODULE__, args, name: __MODULE__)
end

# get/1 ya accede directamente a ETS — correcto, no necesita cambios
```

### Security.JWT: String.to_atom en verify_token — usar existing_atom

```elixir
# En lib/el_paso/security/jwt.ex, en verify_token:
# CAMBIAR:
role: String.to_atom(claims["role"])
# POR:
role: (try do String.to_existing_atom(claims["role"] || "user")
       rescue _ -> :user end)
```

### Plugin.Loader: IO.puts → Logger

```elixir
# En lib/el_paso/plugin/loader.ex, reemplazar TODOS los IO.puts por Logger:
# IO.puts("✅ Plugin de engine cargado: ...") → Logger.info(...)
# IO.puts("⚠️ Plugin no encontrado: ...") → Logger.warning(...)
# IO.puts("❌ Error cargando plugin ...") → Logger.error(...)
# IO.puts("❌ Plugin de engine descargado: ...") → Logger.info(...)
```

### Plugin.Loader: load_all no recibe config del nuevo sistema

```elixir
# ACTUAL: load_all(plugins_config) — recibe mapa
# NUEVO: leer de Config.Loader directamente
def load_all do
  plugins_config = ElPaso.Config.Loader.get()[:plugins] || %{}
  engines = Map.get(plugins_config, :engines, []) || []
  Enum.each(engines, &load_engine_plugin/1)
end
```

Y en Application.start/2 (después de supervisar los hijos):
```elixir
# Al final de start/2, tras {:ok, pid}:
ElPaso.Plugin.Loader.load_all()
ElPaso.Domain.ModelManager.boot_autostart_models()
```

### Config.Wizard: reemplazar stubs por llamada al Mix task

```elixir
# lib/el_paso/config/wizard.ex — reemplazar completamente:
defmodule ElPaso.Config.Wizard do
  @moduledoc "Delegates interactive setup to the mix elpaso.init task."

  def start_wizard do
    IO.puts("\nRun `mix elpaso.init` for the interactive setup wizard.")
    IO.puts("Or use `mix elpaso.engine.add` and `mix elpaso.model.add` directly.\n")
    :ok
  end

  def setup_defaults do
    {:ok, ElPaso.Config.Loader.default_config()}
  end
end
```

---

## 17.9 — Application.start/2: llamadas post-boot

Actualizar el final de `start/2` en `lib/el_paso/application.ex`:

```elixir
@impl Application
def start(_type, _args) do
  children = [
    ElPaso.Config.Loader,
    ElPaso.Repo,
    {Finch, name: ElPasoFinch, pools: %{default: [size: 10]}},
    ElPaso.Security.RateLimiter,
    ElPaso.Engine.Registry,
    ElPaso.Domain.ModelSupervisor,
    ElPaso.Context.PrefixManager,
    ElPaso.Context.Manager,
    ElPaso.Context.SummarizationSupervisor,
    ElPaso.Domain.Router,
    ElPaso.Domain.OutputCache,
    ElPaso.Telemetry.Store,
    ElPaso.Event.Supervisor,
    ElPaso.Domain.AutoTuner,
    {Plug.Cowboy,
     scheme:  :http,
     plug:    ElPaso.HTTP.Server,
     options: [port: 8081, dispatch: dispatch()]}
  ] ++ cluster_children()

  case Supervisor.start_link(children, strategy: :one_for_one, name: ElPaso.Supervisor) do
    {:ok, pid} ->
      # Post-boot: cargar plugins y arrancar modelos con autostart
      ElPaso.Plugin.Loader.load_all()
      ElPaso.Domain.ModelManager.boot_autostart_models()
      warn_if_unconfigured()
      {:ok, pid}

    error ->
      error
  end
end

defp dispatch do
  [
    {:_, [
      {"/v1/chat/ws", ElPaso.HTTP.WebSocketHandler, []},
      {:_, Plug.Cowboy.Handler, {ElPaso.HTTP.Server, []}}
    ]}
  ]
end

defp cluster_children do
  if ElPaso.Config.cluster_enabled?() do
    base = [ElPaso.Cluster.NodeRegistry]
    if ElPaso.Config.cluster_discovery() == "gossip" do
      [{Cluster.Supervisor, [[gossip: [strategy: Cluster.Strategy.Gossip,
         config: [port: 45_892, multicast_addr: "230.1.1.251"]]]]} | base]
    else
      base
    end
  else
    []
  end
end

defp warn_if_unconfigured do
  config = ElPaso.Config.Loader.get()
  if map_size(config[:engines] || %{}) == 0 and length(config[:models] || []) == 0 do
    IO.puts("""

    ╔══════════════════════════════════════════════════════════════╗
    ║  ElPaso started with no engines or models configured.        ║
    ║                                                              ║
    ║  To add an engine:  mix elpaso.engine.add                    ║
    ║  To add a model:    mix elpaso.model.add                     ║
    ║  Quick setup:       mix elpaso.init                          ║
    ║                                                              ║
    ║  Config: ~/.config/elpaso/elpaso.conf                        ║
    ╚══════════════════════════════════════════════════════════════╝
    """)
  end
end
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECCIÓN 18 — PIEZAS FINALES: TODO LO QUE AÚN FALTABA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 18.1 — Engine behaviour: corregir referencias a módulos inexistentes

Reemplazar `lib/el_paso/engine.ex` completamente:

```elixir
defmodule ElPaso.Engine do
  @moduledoc """
  Behaviour for ElPaso inference engines.

  Implement this behaviour to integrate any inference backend:
  local processes (llama-server, vllm), managed services (Ollama),
  remote APIs (OpenAI, Anthropic), or custom wrappers (AirLLM).

  ## Minimal implementation

      defmodule MyEngine do
        @behaviour ElPaso.Engine

        @impl true
        def name, do: :my_engine

        @impl true
        def type, do: :local_process

        @impl true
        def infer(prompt, params, config) do
          # call your backend
          {:ok, %ElPaso.Engine.Response{content: "...", finish_reason: :stop,
            prompt_tokens: 0, completion_tokens: 0, latency_ms: 0}}
        end

        @impl true
        def stream(prompt, params, config, chunk_callback) do
          chunk_callback.(%ElPaso.Engine.Chunk{content: "...", done: true})
          :ok
        end

        @impl true
        def prepare_prefix(prefix, _config), do: prefix

        @impl true
        def health_check(_config), do: :ok

        @impl true
        def format_messages(messages, _context_spec), do: messages
      end
  """

  @doc "Unique engine identifier atom."
  @callback name() :: atom()

  @doc "Engine type: `:local_process`, `:remote_api`, `:managed_service`, or `:airllm_wrapper`."
  @callback type() :: :local_process | :remote_api | :managed_service | :airllm_wrapper

  @doc """
  Runs synchronous inference. Returns the full response or an error.

  - `prompt`  — `%ElPaso.Context.Builder.BuiltPrompt{}` with messages and system prompt.
  - `params`  — inference parameters (`:temperature`, `:max_tokens`, etc.)
  - `config`  — engine configuration map (`:base_url`, `:api_key`, `:model_name`, etc.)
  """
  @callback infer(
              prompt :: ElPaso.Context.Builder.BuiltPrompt.t(),
              params :: map(),
              config :: map()
            ) :: {:ok, ElPaso.Engine.Response.t()} | {:error, reason :: term()}

  @doc """
  Runs streaming inference. Calls `chunk_callback` for each chunk received.
  Returns `:ok` when the stream is complete.
  """
  @callback stream(
              prompt :: ElPaso.Context.Builder.BuiltPrompt.t(),
              params :: map(),
              config :: map(),
              chunk_callback :: (ElPaso.Engine.Chunk.t() -> any())
            ) :: :ok | {:error, reason :: term()}

  @doc "Adapts a prefix block to the format expected by this engine."
  @callback prepare_prefix(prefix :: map(), config :: map()) :: term()

  @doc "Verifies the engine is reachable and operational."
  @callback health_check(config :: map()) :: :ok | {:error, reason :: term()}

  @doc "Formats messages to the engine-specific format before inference."
  @callback format_messages(messages :: [map()], context_spec :: map()) :: term()

  defmacro __using__(_opts) do
    quote do
      @behaviour ElPaso.Engine
    end
  end
end
```

---

## 18.2 — Engine.ChatTemplate: reescribir con API correcta

Reemplazar `lib/el_paso/engine/chat_template.ex` completamente:

```elixir
defmodule ElPaso.Engine.ChatTemplate do
  @moduledoc """
  Formats message lists into the prompt format expected by each model type.

  Returns `{:passthrough, messages}` for OpenAI-compatible models (messages
  are sent as-is) or `{:formatted, string}` for models that need a specific
  text format.
  """

  @doc """
  Formats messages according to the specified chat template.

  ## Parameters
    - messages: list of `%{role: "user"|"assistant"|"system", content: "..."}` maps
    - system_prompt: optional system prompt string (nil if none)
    - template: atom — `:openai`, `:anthropic`, `:llama3`, `:chatml`, `:gemma`, `:mistral`

  ## Returns
    - `{:passthrough, messages}` — send messages as-is (OpenAI/Anthropic engines)
    - `{:formatted, string}` — pre-formatted prompt string for local models
  """
  @spec format([map()], String.t() | nil, atom()) ::
          {:passthrough, [map()]} | {:formatted, String.t()}
  def format(messages, system_prompt, template) do
    case template do
      t when t in [:openai, :anthropic] ->
        {:passthrough, inject_system(messages, system_prompt)}

      :llama3  -> {:formatted, format_llama3(messages, system_prompt)}
      :chatml  -> {:formatted, format_chatml(messages, system_prompt)}
      :gemma   -> {:formatted, format_gemma(messages, system_prompt)}
      :mistral -> {:formatted, format_mistral(messages, system_prompt)}
      _        -> {:formatted, format_chatml(messages, system_prompt)}
    end
  end

  defp inject_system(messages, nil), do: messages
  defp inject_system(messages, ""), do: messages
  defp inject_system(messages, system) do
    has_system = Enum.any?(messages, &(Map.get(&1, :role) == "system" or
                                       Map.get(&1, "role") == "system"))
    if has_system do
      messages
    else
      [%{role: "system", content: system} | messages]
    end
  end

  defp format_llama3(messages, system_prompt) do
    prefix = if system_prompt && system_prompt != "" do
      "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n#{system_prompt}<|eot_id|>\n"
    else
      "<|begin_of_text|>"
    end

    body = messages
    |> Enum.map(fn m ->
      role    = get_role(m)
      content = get_content(m)
      "<|start_header_id|>#{role}<|end_header_id|>\n\n#{content}<|eot_id|>"
    end)
    |> Enum.join("\n")

    prefix <> body <> "\n<|start_header_id|>assistant<|end_header_id|>\n\n"
  end

  defp format_chatml(messages, system_prompt) do
    sys = if system_prompt && system_prompt != "" do
      "<|im_start|>system\n#{system_prompt}<|im_end|>\n"
    else
      ""
    end

    body = messages
    |> Enum.map(fn m ->
      role    = get_role(m)
      content = get_content(m)
      "<|im_start|>#{role}\n#{content}<|im_end|>"
    end)
    |> Enum.join("\n")

    sys <> body <> "\n<|im_start|>assistant\n"
  end

  defp format_gemma(messages, system_prompt) do
    prefix = if system_prompt && system_prompt != "" do
      "<start_of_turn>user\n#{system_prompt}\n"
    else
      ""
    end

    body = messages
    |> Enum.map(fn m ->
      role    = get_role(m)
      content = get_content(m)
      gemma_role = if role == "assistant", do: "model", else: "user"
      "<start_of_turn>#{gemma_role}\n#{content}<end_of_turn>"
    end)
    |> Enum.join("\n")

    prefix <> body <> "\n<start_of_turn>model\n"
  end

  defp format_mistral(messages, system_prompt) do
    messages
    |> Enum.map(fn m -> {get_role(m), get_content(m)} end)
    |> Enum.chunk_every(2)
    |> Enum.map(fn
      [{"user", u}, {"assistant", a}] ->
        sys = if system_prompt && system_prompt != "", do: system_prompt <> "\n\n", else: ""
        "[INST] #{sys}#{u} [/INST] #{a}"
      [{"user", u}] ->
        sys = if system_prompt && system_prompt != "", do: system_prompt <> "\n\n", else: ""
        "[INST] #{sys}#{u} [/INST]"
      other ->
        Enum.map_join(other, " ", fn {_, c} -> c end)
    end)
    |> Enum.join(" ")
  end

  defp get_role(m),    do: Map.get(m, :role, Map.get(m, "role", "user"))
  defp get_content(m), do: Map.get(m, :content, Map.get(m, "content", ""))
end
```

---

## 18.3 — Engine.Dispatcher: reescribir completo

Reemplazar `lib/el_paso/engine/dispatcher.ex`:

```elixir
defmodule ElPaso.Engine.Dispatcher do
  @moduledoc """
  Single entry point for all inference calls.

  Resolves the engine module from config, builds the engine config,
  and delegates to the engine's `infer/3` or `stream/4` callback.
  """

  require Logger
  alias ElPaso.Config.Loader

  @doc """
  Synchronous inference. Resolves engine from model config and calls infer/3.

  Returns `{:ok, %ElPaso.Engine.Response{}}` or `{:error, reason}`.
  """
  @spec infer(String.t(), ElPaso.Context.Builder.BuiltPrompt.t(), map()) ::
          {:ok, ElPaso.Engine.Response.t()} | {:error, term()}
  def infer(model_alias, built_prompt, params) do
    with {:ok, model_config}  <- Loader.get_model(model_alias),
         {:ok, engine_mod}    <- resolve_engine(model_config[:engine]),
         {:ok, engine_config} <- build_engine_config(model_config) do
      merged = merge_params(model_config, params)
      engine_mod.infer(built_prompt, merged, engine_config)
    end
  rescue
    e -> {:error, {:exception, Exception.message(e)}}
  end

  @doc """
  Streaming inference. Calls `chunk_callback` for each chunk.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec stream(String.t(), ElPaso.Context.Builder.BuiltPrompt.t(), map(),
               (ElPaso.Engine.Chunk.t() -> any())) :: :ok | {:error, term()}
  def stream(model_alias, built_prompt, params, chunk_callback) do
    with {:ok, model_config}  <- Loader.get_model(model_alias),
         {:ok, engine_mod}    <- resolve_engine(model_config[:engine]),
         {:ok, engine_config} <- build_engine_config(model_config) do
      merged = merge_params(model_config, params)
      engine_mod.stream(built_prompt, merged, engine_config, chunk_callback)
    end
  rescue
    e -> {:error, {:exception, Exception.message(e)}}
  end

  defp resolve_engine(engine_alias) when is_binary(engine_alias) do
    case engine_alias do
      "llama_server"   -> {:ok, ElPaso.Engine.LlamaServer}
      "llama-server"   -> {:ok, ElPaso.Engine.LlamaServer}
      "vllm"           -> {:ok, ElPaso.Engine.VLLM}
      "openai"         -> {:ok, ElPaso.Engine.OpenAI}
      "anthropic"      -> {:ok, ElPaso.Engine.Anthropic}
      "ollama"         -> {:ok, ElPaso.Engine.Ollama}
      "airllm"         -> {:ok, ElPaso.Engine.AirLLMWrapper}
      "airllm_wrapper" -> {:ok, ElPaso.Engine.AirLLMWrapper}
      other ->
        atom = try do String.to_existing_atom(other) rescue _ -> nil end
        if atom, do: ElPaso.Engine.Registry.get(atom),
                 else: {:error, {:unknown_engine, other}}
    end
  end
  defp resolve_engine(nil), do: {:error, :engine_not_configured}
  defp resolve_engine(a) when is_atom(a), do: resolve_engine(Atom.to_string(a))

  defp build_engine_config(model_config) do
    engine_alias = model_config[:engine]
    global       = Loader.get()
    engine_cfg   = Map.get(global[:engines] || %{}, engine_alias) || %{}

    port = extract_port(model_config[:engine_args]) ||
           extract_port(engine_cfg[:base_args]) ||
           8081

    base_url = engine_cfg[:base_url] || "http://localhost:#{port}/v1"

    {:ok, %{
      base_url:     base_url,
      api_key:      engine_cfg[:api_key] || "sk-local",
      model_name:   model_config[:alias],
      chat_template: get_in(model_config, [:context_spec, :chat_template]) || "chatml"
    }}
  end

  defp merge_params(model_config, request_params) do
    defaults = model_config[:inference_defaults] || %{}
    Map.merge(defaults, request_params || %{})
  end

  defp extract_port(nil), do: nil
  defp extract_port(args) when is_map(args) do
    v = Map.get(args, "--port") || Map.get(args, :"--port")
    if v, do: to_integer_safe(v), else: nil
  end
  defp extract_port(args) when is_list(args) do
    idx = Enum.find_index(args, &(&1 == "--port"))
    if idx, do: Enum.at(args, idx + 1) |> to_integer_safe(), else: nil
  end

  defp to_integer_safe(v) when is_integer(v), do: v
  defp to_integer_safe(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> nil
    end
  end
  defp to_integer_safe(_), do: nil
end
```

---

## 18.4 — Engine.Ollama: reescribir como behaviour real

Reemplazar `lib/el_paso/engine/ollama.ex`:

```elixir
defmodule ElPaso.Engine.Ollama do
  @moduledoc """
  Engine adapter for Ollama. API-compatible with OpenAI.
  Uses LlamaServer adapter internally; only health_check differs.
  """
  @behaviour ElPaso.Engine

  @impl true
  def name, do: :ollama

  @impl true
  def type, do: :managed_service

  @impl true
  defdelegate infer(prompt, params, config),      to: ElPaso.Engine.LlamaServer

  @impl true
  defdelegate stream(prompt, params, config, cb), to: ElPaso.Engine.LlamaServer

  @impl true
  defdelegate prepare_prefix(prefix, config),     to: ElPaso.Engine.LlamaServer

  @impl true
  defdelegate format_messages(msgs, ctx),         to: ElPaso.Engine.LlamaServer

  @impl true
  def health_check(config) do
    base = config[:base_url] || "http://localhost:11434/v1"
    url  = String.replace(base, "/v1", "") <> "/api/tags"
    case Finch.build(:get, url) |> Finch.request(ElPasoFinch, receive_timeout: 3_000) do
      {:ok, %{status: 200}} -> :ok
      _                     -> {:error, :ollama_unavailable}
    end
  rescue
    _ -> {:error, :ollama_unavailable}
  end
end
```

---

## 18.5 — Router.record_outcome: pasar model_alias, no request_id

```elixir
# ACTUAL (bug): llama a ModelManager.record_call_result(request_id, ...)
# request_id es un string de 16 chars hexadecimales, NO es un model_alias
def record_outcome(request_id, outcome, latency_ms) do
  case Storage.update_routing_outcome(request_id, outcome, latency_ms) do
    :ok ->
      ModelManager.record_call_result(request_id, latency_ms, outcome)  # BUG
    error -> error
  end
end
```

Para poder actualizar el ModelWorker, el router necesita saber el model_id.
Añadir lookup en routing_decisions:

```elixir
def record_outcome(request_id, outcome, latency_ms) do
  # Update DB record
  Storage.update_routing_outcome(request_id, outcome, latency_ms)

  # Update ModelWorker stats — need to find which model served this request
  decisions = Storage.query_routing_decisions(
    since: DateTime.add(DateTime.utc_now(), -3600),
    with_outcome: false
  )
  case Enum.find(decisions, &(&1[:request_id] == request_id)) do
    nil -> :ok
    rd  ->
      ElPaso.Domain.ModelManager.record_call_result(
        rd[:selected_model], latency_ms, outcome)
  end
end
```

---

## 18.6 — Router.recent_decisions y stats: implementar real

```elixir
# ACTUAL: siempre devuelven [] y %{}
def recent_decisions(limit \\ 50) do
  ElPaso.Context.Storage.query_routing_decisions(
    since: DateTime.add(DateTime.utc_now(), -86_400)
  ) |> Enum.take(limit)
end

def stats do
  since = DateTime.add(DateTime.utc_now(), -86_400)
  decisions = ElPaso.Context.Storage.query_routing_decisions(since: since, with_outcome: true)

  %{
    total:      length(decisions),
    by_model:   Enum.frequencies_by(decisions, & &1[:selected_model]),
    by_task:    Enum.frequencies_by(decisions, & &1[:task_type]),
    avg_latency_ms: average(Enum.map(decisions, & &1[:latency_ms] || 0))
  }
end

defp average([]), do: 0
defp average(list), do: Enum.sum(list) / length(list) |> Float.round(1)
```

---

## 18.7 — RouterAnalyzer: corregir bug Date.compare sobre DateTime

```elixir
# ACTUAL (bug en split_into_weekly_windows):
# d.decided_at es %DateTime{}, pero Date.compare espera %Date{}
Date.compare(d.decided_at, List.first(week_range)) in [:gt, :eq]
```

Reemplazar `defp split_into_weekly_windows/1`:

```elixir
defp split_into_weekly_windows(decisions) do
  sorted = Enum.sort_by(decisions, & &1.decided_at, DateTime)

  case {List.first(sorted), List.last(sorted)} do
    {nil, _} -> []
    {first, last} ->
      first_date = DateTime.to_date(first.decided_at)
      last_date  = DateTime.to_date(last.decided_at)
      date_range = Date.range(first_date, last_date)

      date_range
      |> Enum.take_every(7)
      |> Enum.map(fn week_start ->
        week_end = Date.add(week_start, 6)
        week_decisions = Enum.filter(sorted, fn d ->
          d_date = DateTime.to_date(d.decided_at)
          Date.compare(d_date, week_start) in [:gt, :eq] and
          Date.compare(d_date, week_end)   in [:lt, :eq]
        end)
        %{week: week_start, decisions: week_decisions}
      end)
      |> Enum.reject(&(&1.decisions == []))
  end
end
```

Y corregir `resolve_since/1` que devuelve `%Date{}` pero Storage espera `%DateTime{}`:

```elixir
defp resolve_since(:last_7d),  do: DateTime.add(DateTime.utc_now(), -7  * 86_400)
defp resolve_since(:last_30d), do: DateTime.add(DateTime.utc_now(), -30 * 86_400)
defp resolve_since(:last_90d), do: DateTime.add(DateTime.utc_now(), -90 * 86_400)
```

---

## 18.8 — AutoTuner: corregir cluster_mode? y envolver en rescue

```elixir
# CAMBIO 1: cluster_mode? → cluster_enabled? (línea ~605 en Context.Manager también)
# En AutoTuner.do_auto_tune, buscar:
#   if ElPaso.Config.cluster_mode?() do
# y reemplazar por:
#   if ElPaso.Config.cluster_enabled?() do

# CAMBIO 2: envolver handle_info(:run_auto_tune) en rescue para que un fallo
# no detenga el GenServer:
@impl true
def handle_info(:run_auto_tune, state) do
  try do
    do_auto_tune(state)
  rescue
    e ->
      Logger.error("[AutoTuner] Auto-tune failed: #{Exception.message(e)}")
      schedule_next_run()
      {:noreply, state}
  end
end
```

---

## 18.9 — Context.Manager: fix cluster_mode? y :session_states init

```elixir
# CAMBIO 1: línea ~605, reemplazar:
is_cluster = Config.cluster_mode?()
# por:
is_cluster = ElPaso.Config.cluster_enabled?()

# CAMBIO 2: init/1 crea la tabla ETS correctamente pero luego
# get_or_create_session llama a Storage.create_session directamente
# sin pasar por GenServer → race condition.
# La corrección de la Sección 17.6 (handle_call {:get_or_create})
# ya soluciona esto. Asegurarse de que la llamada directa a
# Storage.create_session en get_or_create_session se elimina y
# pasa por do_get_or_create/2.
```

---

## 18.10 — Config.ex: añadir cluster_mode? como alias de cluster_enabled?

Existen módulos que llaman `Config.cluster_mode?()`. Para evitar reescribir
todos esos módulos, añadir el alias en `ElPaso.Config`:

```elixir
# En lib/el_paso/config.ex, añadir:
@doc false
@deprecated "Use cluster_enabled?/0 instead"
def cluster_mode?, do: cluster_enabled?()
```

Esto evita crash inmediato mientras se actualizan los módulos. Después
hacer la búsqueda global y reemplazar:

```bash
grep -rn "cluster_mode?" lib/ | grep -v "config.ex"
# → reemplazar cada ocurrencia con cluster_enabled?()
```

---

## 18.11 — Domain.Router: eliminar ModelState local (struct duplicado)

El Router define internamente su propio `defmodule ModelState` (struct local).
Después de crear `ElPaso.Domain.ModelState` (Sección 17.5), el struct local
del Router queda obsoleto y en conflicto.

Eliminar de `lib/el_paso/domain/router.ex` el bloque:
```elixir
defmodule ModelState do
  defstruct [...]
end
```

Y añadir en su lugar:
```elixir
alias ElPaso.Domain.ModelState
alias ElPaso.Domain.ModelManager
```

---

## 18.12 — HTTP.Server: corregir plug stack y eliminar start_link extra

```elixir
# REEMPLAZAR el inicio de HTTP.Server:
defmodule ElPaso.HTTP.Server do
  use Plug.Router

  plug Plug.Logger
  plug :fetch_query_params
  plug :match
  plug :dispatch

  # ELIMINAR completamente:
  # def start_link(_args) do
  #   {:ok, _} = Plug.Cowboy.http(__MODULE__, [])
  #   {:ok, self()}
  # end
```

---

## 18.13 — Context.PrefixManager: añadir name: en start_link

```elixir
# En lib/el_paso/context/prefix_manager.ex:
def start_link(args) do
  GenServer.start_link(__MODULE__, args, name: __MODULE__)
end
```

`PrefixManager.get/1` ya accede a ETS directamente — correcto para lecturas.
`PrefixManager.build/2` y `update/2` deben pasar por GenServer para serializar
escrituras:

```elixir
def build(session_id, config) do
  GenServer.call(__MODULE__, {:build, session_id, config})
end

def update(session_id, new_content) do
  GenServer.call(__MODULE__, {:update, session_id, new_content})
end

@impl true
def handle_call({:build, session_id, config}, _from, state) do
  result = do_build(session_id, config)
  {:reply, result, state}
end

@impl true
def handle_call({:update, session_id, content}, _from, state) do
  result = do_update(session_id, content)
  {:reply, result, state}
end
```

Mover la lógica actual de `build/2` y `update/2` a `defp do_build/2`
y `defp do_update/2`.

---

## 18.14 — Router.Cluster: corregir el if sin else

```elixir
# ACTUAL (bug): if sin else no hace early-return en Elixir
defp distributed_select(local_scores, features) do
  if Enum.empty?(NodeRegistry.all_nodes()) do
    select_best_with_node(local_scores, Node.self())
  end
  # El código continúa ejecutando el bloque de nodos remotos siempre
  remote = NodeRegistry.all_nodes() |> ...
  all_candidates = local + remote
  ...
end
```

Corrección:

```elixir
defp distributed_select(local_scores, features) do
  if Enum.empty?(NodeRegistry.all_nodes()) do
    select_best_with_node(local_scores, Node.self())
  else
    remote_candidates =
      NodeRegistry.all_nodes()
      |> Enum.filter(&(&1 != Node.self()))
      |> Task.async_stream(
           fn node ->
             :rpc.call(node, ElPaso.Domain.Router, :local_scores, [features], 5_000)
           end,
           timeout: 5_000,
           on_timeout: :kill_task
         )
      |> Enum.flat_map(fn
           {:ok, {:ok, scores}} -> [{node, scores}]
           _                    -> []
         end)

    all_candidates = [{Node.self(), local_scores} | remote_candidates]

    all_candidates
    |> Enum.flat_map(fn {node, scores} ->
         Enum.map(scores, fn {model_id, score} -> {model_id, score, node} end)
       end)
    |> Enum.max_by(fn {_, score, _} -> score end, fn -> {nil, 0, Node.self()} end)
    |> case do
         {nil, _, _} -> {:error, :no_models_available}
         {model_id, _, node} -> {:ok, model_id, node}
       end
  end
end
```

---

## 18.15 — Rutas del Dashboard: corregir mismatch URL

```elixir
# En lib/el_paso/http/server.ex, reemplazar:
get "/dashboard" do
  ElPaso.HTTP.Dashboard.call(conn, [])
end

# Por:
forward "/dashboard", to: ElPaso.HTTP.Dashboard
```

Y en el HTML del Dashboard, asegurarse de que todas las llamadas
`fetch(...)` usan rutas relativas sin prefijo `/dashboard/`:

```javascript
// ANTES:
fetch('/dashboard/api/state')

// DESPUÉS (con forward, las rutas internas de Dashboard son relativas):
fetch('/dashboard/api/state')  // correcto si Dashboard registra get "/api/state"
// O si Dashboard usa rutas sin prefijo:
fetch('/api/state')  // solo correcto si se monta como root
```

La opción más limpia con `forward`: Dashboard registra `get "/api/state"`,
el JS hace `fetch('/dashboard/api/state')`. Con `forward "/dashboard"`,
Plug quita el prefijo y Dashboard ve `/api/state`. El JS actual es correcto.
Solo hay que cambiar el router de `get "/dashboard"` a `forward "/dashboard"`.

---

## 18.16 — Migraciones Ecto: las 5 completas

Crear los archivos en `priv/repo/migrations/`:

### 20250101000001_create_sessions.exs

```elixir
defmodule ElPaso.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\"", "SELECT 1"

    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :context_mode, :string, null: false, default: "transparent"
      add :user_id, :string
      add :metadata, :map, default: %{}
      timestamps(type: :utc_datetime_usec, inserted_at: :created_at,
                 updated_at: :last_active_at)
    end

    create index(:sessions, [:last_active_at])
    create index(:sessions, [:user_id])
  end
end
```

### 20250101000002_create_messages.exs

```elixir
defmodule ElPaso.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS vector", "SELECT 1"

    create table(:messages) do
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all),
          null: false
      add :sequence_number, :integer, null: false
      add :role, :string, null: false
      add :content, :text, null: false
      add :token_estimate, :integer, null: false, default: 0
      add :model_id, :string
      add :archived_at, :utc_datetime_usec
      add :embedding, :vector, size: 768
      timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
    end

    create index(:messages, [:session_id, :sequence_number])
    create index(:messages, [:session_id],
      where: "archived_at IS NULL", name: :idx_messages_session_active)
  end
end
```

### 20250101000003_create_conversation_summaries.exs

```elixir
defmodule ElPaso.Repo.Migrations.CreateConversationSummaries do
  use Ecto.Migration

  def change do
    create table(:conversation_summaries) do
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all),
          null: false
      add :content, :text, null: false
      add :covers_until_message_id, references(:messages, on_delete: :nilify_all)
      add :token_estimate, :integer, null: false, default: 0
      add :generated_by_model, :string, null: false
      add :generated_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
      add :archived_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
    end

    create index(:conversation_summaries, [:session_id, :generated_at])
  end
end
```

### 20250101000004_create_routing_decisions.exs

```elixir
defmodule ElPaso.Repo.Migrations.CreateRoutingDecisions do
  use Ecto.Migration

  def change do
    create table(:routing_decisions, primary_key: false) do
      add :request_id, :string, primary_key: true
      add :session_id, references(:sessions, type: :binary_id, on_delete: :nilify_all)
      add :selected_model, :string, null: false
      add :runner_up, :string
      add :task_type, :string, null: false
      add :complexity_score, :float, null: false
      add :token_estimate, :integer, null: false, default: 0
      add :feature_vector, :map, null: false, default: %{}
      add :scores, :map, null: false, default: %{}
      add :reason, :string, null: false
      add :outcome, :string
      add :latency_ms, :integer
      add :decision_latency_us, :integer
      add :decided_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
    end

    create index(:routing_decisions, [:session_id, :decided_at])
    create index(:routing_decisions, [:selected_model, :task_type])
  end
end
```

### 20250101000005_create_auto_tune_runs.exs

```elixir
defmodule ElPaso.Repo.Migrations.CreateAutoTuneRuns do
  use Ecto.Migration

  def change do
    create table(:auto_tune_runs) do
      add :applied_changes, :integer, null: false, default: 0
      add :changes_json, :text
      add :ran_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
    end

    create index(:auto_tune_runs, [:ran_at])
  end
end
```

✓ Verificación: `mix ecto.migrate` aplica las 5 migraciones sin errores.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CHECKLIST FINAL DE VERIFICACIÓN — EXHAUSTIVO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ejecutar en este orden. ElPaso está terminado cuando todos pasan.

```bash
# ─── COMPILACIÓN ───────────────────────────────────────────────────────────

mix compile --warnings-as-errors
# → 0 warnings, 0 errors

# Sin referencias a módulos inexistentes
grep -rn "ModelDownloaderRegistry\|ElPaso\.Context\.BuiltPrompt\b\|ElPaso\.Context\.PrefixBlock\b" lib/
# → 0 resultados

# Sin atom injection
grep -rn "String\.to_atom(" lib/ | grep -v "to_existing_atom\|#"
# → 0 resultados

# Sin cluster_mode?
grep -rn "cluster_mode?" lib/ | grep -v "config.ex\|#"
# → 0 resultados (solo el alias deprecated en config.ex)

# Sin IO.puts en producción (excepto el banner de arranque)
grep -rn "IO\.puts\|IO\.inspect" lib/ | grep -v "mix/\|#\|application.ex"
# → 0 resultados

# ─── BASE DE DATOS ──────────────────────────────────────────────────────────

mix ecto.create
mix ecto.migrate
# → 5 migraciones aplicadas sin error

# ─── ARRANQUE SIN CONFIGURACIÓN ─────────────────────────────────────────────

rm -f ~/.config/elpaso/elpaso.conf
mix run --no-halt &
sleep 3
# → NO hay RuntimeError, ArgumentError ni FunctionClauseError en el log
# → SÍ aparece el banner "ElPaso started with no engines or models configured"

# ─── ENDPOINTS HTTP ─────────────────────────────────────────────────────────

curl -s http://localhost:8081/health | jq .
# → {"status":"ok","version":"1.0.0"}

curl -s http://localhost:8081/v1/models | jq '.data | length'
# → 0 (sin modelos configurados)

curl -s -X POST http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"hi"}]}' | jq .error.type
# → "no_models_available"

# ─── REGISTRO DE MOTOR Y MODELO ─────────────────────────────────────────────

mix elpaso.engine.add --alias llama-fast --type local_process \
  --binary /usr/bin/llama-server --port 8081 --gpu-layers 35
# → ✓ Engine 'llama-fast' registered.

mix elpaso.model.add --alias fast --engine llama-fast \
  --path ~/models/fast.gguf --type chat --template llama3
# → ✓ Model 'fast' registered.

# Persistencia en disco
cat ~/.config/elpaso/elpaso.conf | jq '.engines | keys'
# → ["llama-fast"]
cat ~/.config/elpaso/elpaso.conf | jq '[.models[].alias]'
# → ["fast"]

# ─── STORAGE REAL ───────────────────────────────────────────────────────────

mix run -e '
  {:ok, sid} = ElPaso.Context.Storage.create_session()
  IO.puts("Created: #{sid}")
  {:ok, _} = ElPaso.Context.Storage.get_session(sid)
  IO.puts("Found: ok")
  {:error, :not_found} = ElPaso.Context.Storage.get_session("no-existe")
  IO.puts("Not found: ok")
'
# → Created: <real-uuid>
# → Found: ok
# → Not found: ok

# ─── CONTEXT.MANAGER ────────────────────────────────────────────────────────

mix run -e '
  {:ok, sid, _state} = ElPaso.Context.Manager.get_or_create_session()
  IO.puts("Session: #{sid}")
  {:ok, sid2, _} = ElPaso.Context.Manager.get_or_create_session(sid)
  IO.puts("Same session: #{sid == sid2}")
'
# → Session: <uuid>
# → Same session: true

# ─── INFERENCIA REAL (con llama-server arrancado) ───────────────────────────

# Arrancar el motor primero (adaptar a tu setup)
# ./llama.sh fast &
# sleep 5

curl -s -X POST http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"Di hola en 5 palabras"}]}' \
  | jq '{content: .choices[0].message.content, session: .elpaso.session_id}'
# → {"content": "...", "session": "<uuid>"}

# ─── CONTEXTO PERSISTENTE ───────────────────────────────────────────────────

SID=$(curl -s -X POST http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"Mi nombre es Lorenzo"}]}' \
  | jq -r '.elpaso.session_id')

echo "Session: $SID"

curl -s -X POST http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"auto\",\"elpaso\":{\"session_id\":\"$SID\"},
       \"messages\":[{\"role\":\"user\",\"content\":\"¿Cuál es mi nombre?\"}]}" \
  | jq -r '.choices[0].message.content'
# → "Tu nombre es Lorenzo."

# ─── STREAMING ──────────────────────────────────────────────────────────────

curl -s -X POST http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","stream":true,"messages":[{"role":"user","content":"Cuenta del 1 al 5"}]}' \
  | grep "data:" | head -10
# → data: {"id":"chatcmpl-...","choices":[{"delta":{"content":"1"},...}]}
# → ...
# → data: [DONE]

# ─── CLI COMPLETO ───────────────────────────────────────────────────────────

mix elpaso engine list
# → tabla con llama-fast

mix elpaso model list
# → tabla con fast, engine: llama-fast, status: cold

mix elpaso.engine.test llama-fast
# → Testing engine 'llama-fast'... ✓ OK  (si el servidor está arrancado)
# → Testing engine 'llama-fast'... ✗ Failed: {:error, :unavailable}  (si está parado)

# ─── AUTOTUNER ──────────────────────────────────────────────────────────────

mix run -e 'ElPaso.Domain.AutoTuner.run_now()'
# → No RuntimeError, log: "Auto-tune: sin cambios aplicables"

# ─── DOCUMENTACIÓN ──────────────────────────────────────────────────────────

mix docs
# → 0 errores, docs generados en doc/

# ─── CALIDAD ────────────────────────────────────────────────────────────────

mix credo --strict
# → 0 issues críticos nuevos

# ─── TELEMETRÍA ─────────────────────────────────────────────────────────────

mix run -e '
  :telemetry.attach("test", [:elpaso, :inference, :complete],
    fn _event, measurements, meta, _ ->
      IO.puts("Latency: #{measurements.latency_ms}ms, model: #{meta.model_id}")
    end, nil)
  # (hacer un request y ver el log)
'
# → "Latency: Xms, model: fast"
```

═══════════════════════════════════════════════════════════════════════════════
FIN DEL PROMPT — VERSIÓN DEFINITIVA COMPLETA
═══════════════════════════════════════════════════════════════════════════════
