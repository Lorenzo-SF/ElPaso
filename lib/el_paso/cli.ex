defmodule ElPaso.CLI do
  @moduledoc """
  CLI principal para elpaso.
  """

  alias Zaguan.Drawer.Components.{Header, Table}

  def main([]) do
    IO.puts("""
    ElPaso - Multi-Model LLM Proxy

    Uso: elpaso <comando> [opciones]

    Escribe 'elpaso --help' para ver todos los comandos disponibles.
    """)
  end

  def main(["--help"]) do
    IO.puts("""
    ElPaso - Multi-Model LLM Proxy

    USO:
      elpaso <comando> [opciones]

    COMANDOS PRINCIPALES:

      init         Inicializar configuración de ElPaso
      model        Gestión de modelos de inferencia
      engine       Gestión de motores de inferencia
      personality  Gestión de personalidades/roles
      profile      Gestión de perfiles (modelo+engine+personalidad)
      config       Gestión de configuración
      db           Gestión de base de datos
      server       Gestionar servidor HTTP
      router       Estadísticas y auto-tuneo del router
      bench        Ejecutar benchmarks
      context      Gestionar contextos de sesión
      cluster      Estado del cluster

    SUBCOMANDOS POR COMANDO:

      init
      model add/list/delete/update/show/start/stop
      engine add/list/delete/update/show/test
      personality add/list/delete/show/use
      profile add/list/delete/show
      config show/set/reload
      db create/migrate/status
      server start/stop/restart/status/log
      router stats/tune/rules
      bench run
      context list/show/clear
      cluster status/nodes/join

    VER AYUDA ESPECÍFICA:
      elpaso model --help
      elpaso engine --help
      elpaso personality --help
      elpaso config --help
      elpaso server --help
      elpaso router --help
      elpaso bench --help
      elpaso context --help
      elapso cluster --help

    Ejemplos:
      elpaso --help             # Esta guía
      elpaso model --help      # Ver ayuda de model
      elpaso model list        # Listar modelos
      elpaso model add ...     # Añadir modelo
      elpaso server start     # Iniciar servidor
      elpaso server status    # Ver estado
    """)
  end

  def main(["model", "--help"]) do
    IO.puts("""
    ELPASO MODEL

    Gestión de modelos de inferencia.

    COMANDOS:

      elpaso model add          Añadir un nuevo modelo
      elpaso model list       Listar todos los modelos
      elpaso model delete     Eliminar un modelo
      elpaso model update    Actualizar un modelo
      elpaso model show      Mostrar detalles de un modelo

    USO:

      elpaso model add [opciones]
      elpaso model list
      elpaso model delete --name <nombre>
      elpaso model update --name <nombre> [opciones]
      elpaso model show --name <nombre>

    OPCIONES:

      --name <nombre>        Nombre único del modelo (REQUERIDO para delete/update/show)
      --engine <engine>    ID del motor (REQUERIDO para add)
      --url <url>          URL del endpoint (REQUERIDO para add)
      --api-key <key>      API key (opcional)
      --description <desc>  Descripción (opcional)
      --active             Si está activo (default: true)
      --max-tokens <n>     Máximo de tokens (default: 4096)
      --temperature <t>     Temperatura (default: 0.7)
      --top-p <p>          Top-p (default: 1.0)

    EJEMPLOS:

      # Listar todos los modelos
      elpaso model list

      # Añadir modelo
      elpaso model add --name llama-3-8b --engine llama-server --url http://localhost:8080/v1

      # Ver detalles de un modelo
      elpaso model show --name gemma

      # Actualizar modelo
      elpaso model update --name gemma --temperature 0.5

      # Activar/desactivar modelo
      elpaso model update --name gemma --active false

      # Eliminar modelo
      elpaso model delete --name gemma
    """)
  end

  def main(["engine", "--help"]) do
    IO.puts("""
    ELPASO ENGINE

    Gestión de motores de inferencia.

    COMANDOS:

      elpaso engine add          Añadir un nuevo motor
      elpaso engine list       Listar todos los motores
      elpaso engine delete     Eliminar un motor
      elpaso engine update    Actualizar un motor
      elpaso engine show      Mostrar detalles de un motor

    USO:

      elpaso engine add [opciones]
      elpaso engine list
      elpaso engine delete --name <nombre>
      elpaso engine update --name <nombre> [opciones]
      elpaso engine show --name <nombre>

    OPCIONES:

      --name <nombre>      Nombre único del motor (REQUERIDO para delete/update/show)
      --adapter <adapter>Tipo de adaptador (REQUERIDO para add)
      --base-url <url>   URL base del motor (REQUERIDO para add)
      --api-key <key>    API key (opcional)
      --description <desc> Descripción (opcional)
      --active           Si está activo (default: true)
      --timeout <ms>     Timeout en ms (default: 60000)

    ADAPTADORES:

      llama      llama.cpp servidor HTTP
      vllm       vLLM API GPU
      airllm      AirLLM CPU
      ollama     Ollama (local o remoto)
      openai     OpenAI API
      anthropic Anthropic API

    EJEMPLOS:

      # Listar todos los motores
      elpaso engine list

      # Añadir motor
      elpaso engine add --name llama-server --adapter llama --base-url http://localhost:8080/v1

      # Ver detalles
      elpaso engine show --name llama-server

      # Actualizar timeout
      elpaso engine update --name llama-server --timeout 120000

      # Desactivar motor
      elpaso engine update --name llama-server --active false

      # Eliminar motor
      elpaso engine delete --name llama-server
    """)
  end

  def main(["config", "--help"]) do
    IO.puts("""
    ELPASO CONFIG

    Gestión de configuración del sistema.

    COMANDOS:

      elpaso config show        Mostrar configuración actual
      elpaso config reload    Recargar configuración desde DB
      elpaso config set      Establecer configuración

    USO:

      elpaso config show
      elpaso config reload
      elpaso config set --key valor

    OPCIONES COMUNES:

      --env <entorno>     Entorno: dev, test, prod
      --port <puerto>    Puerto HTTP (default: 8080)
      --log-level <nivel> Nivel de log: debug, info, warn, error

    EJEMPLOS:

      # Ver configuración actual
      elpaso config show

      # Recargar configuración
      elpaso config reload

      # Variables de entorno
      export ELPASO_PORT=8080
      export ELPASO_INFERENCE_URL=http://localhost:8081/v1
      export ELPASO_INFERENCE_API_KEY=sk-test
    """)
  end

  def main(["router", "--help"]) do
    IO.puts("""
    ELPASO ROUTER

    Gestión del sistema de enrutamiento de modelos.

    COMANDOS:

      elpaso router stats     Mostrar estadísticas de routing
      elpaso router tune    Auto-tuneo de reglas de routing
      elpaso router rules    Mostrar reglas activas

    USO:

      elpaso router stats
      elpaso router tune
      elpaso router rules [--model <model_id>]

    OPCIONES:

      --model <id>       Filtrar por modelo específico
      --task <tipo>      Filtrar por tipo de tarea
      --limit <n>        Número de resultados (default: 100)

    EJEMPLOS:

      # Ver todas las estadísticas
      elpaso router stats

      # Ver estadísticas de un modelo
      elpaso router stats --model gpt-4

      # Auto-tuneo
      elpaso router tune

      # Ver reglas activas
      elpaso router rules
    """)
  end

  def main(["bench", "--help"]) do
    IO.puts("""
    ELPASO BENCH

    Ejecutar benchmarks de rendimiento.

    COMANDOS:

      elpasar bench run      Ejecutar benchmark

    USO:

      elpaso bench run [opciones]

    OPCIONES:

      --models <ids>        Modelos a testar (comma-separated)
      --prompt <prompt>    Prompt de prueba
      --concurrency <n>    Número de peticiones concurrentes
      --duration <seg>     Duración en segundos
      --max-tokens <n>     Máximo de tokens de salida
      --temperature <t>    Temperatura

    EJEMPLOS:

      # Benchmark básico
      elpaso bench run

      # Benchmark con modelos específicos
      elpaso bench run --models gpt-4,claude-3

      # Benchmark de carga
      elpaso bench run --concurrency 10 --duration 60
    """)
  end

  def main(["context", "--help"]) do
    IO.puts("""
    ELPASO CONTEXT

    Gestión de contextos de sesión.

    COMANDOS:

      elpaso context list      Listar sesiones activas
      elpaso context show    Mostrar contexto de sesión
      elpaso context clear  Limpiar contextos

    USO:

      elpaso context list
      elpaso context show <session_id>
      elpaso context clear [--session <id>|--all]

    OPCIONES:

      --session <id>       ID de sesión
      --all              Todas las sesiones
      --user <usuario>    Filtrar por usuario
      --limit <n>        Límite de resultados

    EJEMPLOS:

      # Listar sesiones activas
      elpaso context list

      # Ver contexto de sesión
      elpeso context show abc123

      # Limpiar todas las sesiones
      elpaso context clear --all
    """)
  end

  def main(["cluster", "--help"]) do
    IO.puts("""
    ELPASO CLUSTER

    Gestión y monitorización del cluster.

    COMANDOS:

      elpaso cluster status    Estado del cluster
      elpaso cluster nodes     Lista de nodos
      elpaso cluster join      Unirse a cluster existente

    USO:

      elpaso cluster status
      elpaso cluster nodes
      elpaso cluster join --nodes ip1,ip2

    OPCIONES:

      --discovery <modo>    Modo de descubrimiento: gossip, static
      --nodes <ips>        Nodos iniciales (comma-separated)
      --port <puerto>     Puerto de cluster

    MODO GOSSIP:

      Usa libcluster para descubrimiento automático via multicast.
      Puerto: 45892

    MODO STATIC:

      Lista estática de nodos en configuración.

    EJEMPLOS:

      # Ver estado
      elpaso cluster status

      # Ver nodos
      elpaso cluster nodes

      # Unirse con gossip
      elpaso cluster join --discovery gossip
    """)
  end

  def main(args) do
    if requires_app?(args) do
      Application.put_env(:elpaso, :cli_mode, true)

      case Application.ensure_all_started(:elpaso) do
        {:ok, _} ->
          route_command(args)

        {:error, {app, reason}} ->
          IO.puts("❌ Error al iniciar la aplicación #{app}: #{inspect(reason)}")
          IO.puts("   Asegúrate de que PostgreSQL está corriendo y la DB existe.")
          IO.puts("   Crea la DB con:  mix ecto.create && mix ecto.migrate")
          System.halt(1)
      end
    else
      route_command(args)
    end
  end

  defp requires_app?(args) do
    case args do
      ["server" | _] -> false
      ["init" | _] -> false
      ["config" | _] -> false
      ["router" | _] -> false
      ["bench" | _] -> false
      ["context" | _] -> false
      ["cluster" | _] -> false
      ["--help"] -> false
      [] -> false
      _ -> true
    end
  end

  defp route_command(args) do
    case args do
      ["init" | rest] -> handle_init(rest)
      ["model" | rest] -> handle_model(rest)
      ["engine" | rest] -> handle_engine(rest)
      ["personality" | rest] -> handle_personality(rest)
      ["profile" | rest] -> handle_profile(rest)
      ["config" | rest] -> handle_config(rest)
      ["db" | rest] -> handle_db(rest)
      ["server" | rest] -> handle_server(rest)
      ["router" | rest] -> handle_router(rest)
      ["bench" | rest] -> handle_bench(rest)
      ["context" | rest] -> handle_context(rest)
      ["cluster" | rest] -> handle_cluster(rest)
      _ -> IO.puts("Comando desconocido. Usa 'elpaso --help' para ver los comandos disponibles.")
    end
  end

  # ==================== INIT HANDLERS ====================

  defp handle_init(_) do
    config_dir = Path.expand("~/.config/elpaso")
    config_file = Path.join(config_dir, "elpaso.conf")

    File.mkdir_p!(config_dir)

    if File.exists?(config_file) do
      IO.puts("ℹ️  Configuración ya existe en #{config_file}")
    else
      default_config = """
      # ElPaso Configuration

      [http]
      port = 8080
      host = "localhost"

      [models]
      default_engine = "llama_server"

      [logging]
      level = "info"

      [telemetry]
      enabled = true

      [cluster]
      enabled = false
      discovery = "gossip"
      """

      File.write!(config_file, default_config)
      IO.puts("✅ Configuración creada en #{config_file}")
    end

    IO.puts("✅ ElPaso inicializado")
  end

  # ==================== DB HANDLERS ====================

  defp handle_db(["create" | _]) do
    config =
      Ecto.Repo.Supervisor.parse_url(
        System.get_env("DATABASE_URL", "postgresql://postgres:postgres@localhost/elpaso")
      )

    db_name = config[:database]

    # Conectar a postgres sin especificar DB para crear la nuestra
    create_config = Keyword.put(config, :database, "postgres")

    case Postgrex.start_link(create_config) do
      {:ok, conn} ->
        case Postgrex.query(conn, "CREATE DATABASE #{db_name}", []) do
          {:ok, _} ->
            IO.puts("✅ Base de datos '#{db_name}' creada")
            GenServer.stop(conn)

          {:error, %{postgres: %{code: :duplicate_database}}} ->
            IO.puts("ℹ️  Base de datos '#{db_name}' ya existe")
            GenServer.stop(conn)

          {:error, reason} ->
            IO.puts("❌ Error al crear la base de datos: #{inspect(reason)}")
            System.halt(1)
        end

      {:error, reason} ->
        IO.puts("❌ No se pudo conectar a PostgreSQL: #{inspect(reason)}")
        IO.puts("   Asegúrate de que PostgreSQL está corriendo.")
        System.halt(1)
    end
  end

  defp handle_db(["migrate" | _]) do
    path = Application.app_dir(:elpaso, "priv/repo/migrations")

    case Ecto.Migrator.run(ElPaso.Repo, path, :up, all: true) do
      [] ->
        IO.puts("ℹ️  No hay migraciones pendientes")

      migrations ->
        IO.puts("✅ #{length(migrations)} migración(es) aplicada(s)")
    end
  end

  defp handle_db(["status" | _]) do
    path = Application.app_dir(:elpaso, "priv/repo/migrations")
    status = Ecto.Migrator.migrations(ElPaso.Repo, path)

    if status == [] do
      IO.puts("No hay migraciones")
    else
      rows = Enum.map(status, fn {state, version, name} ->
        state_str =
          case state do
            :up -> "✅ Aplicada"
            :down -> "⬜ Pendiente"
            :missing -> "❌ Faltante"
          end

        [to_string(version), name, state_str]
      end)

      Table.print(
        headers: ["Versión", "Nombre", "Estado"],
        rows: rows,
        table_border: :rounded,
        headers_color: :cyan
      )
    end
  end

  defp handle_db([]) do
    IO.puts("Usa 'elpaso db --help' para ver ayuda.")
    IO.puts("Comandos: create, migrate, status")
  end

  # ==================== HANDLERS ====================

  defp handle_model(["list" | _]) do
    case ElPaso.Domain.ModelManager.list_models() do
      [] ->
        IO.puts("No hay modelos registrados")

      models ->
        rows = Enum.map(models, fn m ->
          [m.name, m.engine_id, m.url, to_string(m.active)]
        end)

        Table.print(
          headers: ["Name", "Engine", "URL", "Active"],
          rows: rows,
          table_border: :rounded,
          headers_color: :cyan
        )
    end
  end

  defp handle_model(["delete" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.ModelManager.delete_model(name) do
        :ok ->
          IO.puts("✅ Modelo '#{name}' eliminado exitosamente")

        {:error, reason} ->
          IO.puts("❌ Error al eliminar modelo: #{reason}")
      end
    else
      IO.puts("❌ Error: Falta --name")
      IO.puts("Uso: elpaso model delete --name <nombre>")
    end
  end

  defp handle_model(["update" | rest]) do
    name = get_opt(rest, :name)

    if name do
      # Parse options from command line arguments
      attrs = %{
        active: get_opt(rest, :active),
        max_tokens: get_opt(rest, :max_tokens) |> parse_int(),
        temperature: get_opt(rest, :temperature) |> parse_float(),
        top_p: get_opt(rest, :top_p) |> parse_float()
      }

      # Filter out nil values
      attrs = Enum.filter(attrs, fn {_, val} -> val != nil end) |> Map.new()

      case ElPaso.Domain.ModelManager.update_model(name, attrs) do
        {:ok, _model} ->
          IO.puts("✅ Modelo '#{name}' actualizado exitosamente")

        {:error, reason} ->
          IO.puts("❌ Error al actualizar modelo: #{reason}")
      end
    else
      IO.puts("❌ Error: Falta --name")
      IO.puts("Uso: elpaso model update --name <nombre> [opciones]")
    end
  end

  defp handle_model(["show" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.ModelManager.get_model(name) do
        nil ->
          IO.puts("❌ Modelo no encontrado")

        model ->
          IO.puts("Modelo: #{model.name}")
          IO.puts("  Engine: #{model.engine_id}")
          IO.puts("  URL: #{model.url}")
          IO.puts("  Active: #{model.active}")
          IO.puts("  Max tokens: #{model.max_tokens || 4096}")
      end
    else
      IO.puts("❌ Error: Falta --name")
      IO.puts("Uso: elpaso model show --name <nombre>")
    end
  end

  defp handle_model(["start" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.ModelManager.start_model(name) do
        {:ok, _model} ->
          IO.puts("✅ Modelo '#{name}' iniciado exitosamente")

        {:error, reason} ->
          IO.puts("❌ Error al iniciar modelo: #{reason}")
      end
    else
      IO.puts("❌ Error: Falta --name")
      IO.puts("Uso: elpaso model start --name <nombre>")
    end
  end

  defp handle_model(["stop" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.ModelManager.stop_model(name) do
        {:ok, _model} ->
          IO.puts("✅ Modelo '#{name}' detenido exitosamente")

        {:error, reason} ->
          IO.puts("❌ Error al detener modelo: #{reason}")
      end
    else
      IO.puts("❌ Error: Falta --name")
      IO.puts("Uso: elpaso model stop --name <nombre>")
    end
  end

  defp handle_model(["add" | rest]) do
    # Parse options from command line arguments
    name = get_opt(rest, :name)
    engine_id = get_opt(rest, :engine)
    url = get_opt(rest, :url)

    if name && engine_id && url do
      attrs = %{
        name: name,
        engine_id: engine_id,
        url: url,
        api_key: get_opt(rest, :api_key),
        description: get_opt(rest, :description),
        active: get_opt(rest, :active) || true,
        max_tokens: get_opt(rest, :max_tokens) |> parse_int(),
        temperature: (get_opt(rest, :temperature) || get_opt(rest, :temp)) |> parse_float(),
        top_p: get_opt(rest, :top_p) |> parse_float()
      }

      case ElPaso.Domain.ModelManager.create_model(attrs) do
        {:ok, _model} ->
          IO.puts("✅ Modelo '#{name}' creado exitosamente")

        {:error, reason} ->
          IO.puts("❌ Error al crear modelo: #{reason}")
      end
    else
      IO.puts("❌ Error: Faltan parámetros requeridos")
      IO.puts("Uso: elpaso model add --name <name> --engine <engine> --url <url> [opciones]")
    end
  end

  defp handle_model([]) do
    IO.puts("Usa 'elpaso model --help' para ver ayuda del comando model.")
  end

  defp handle_model(args) do
    handle_model(["list" | args])
  end

  defp handle_engine(["list" | _]) do
    case ElPaso.Domain.EngineManager.list_engines() do
      [] ->
        IO.puts("No hay motores registrados")

      engines ->
        rows = Enum.map(engines, fn e ->
          [e.name, e.adapter, e.base_url, to_string(e.active)]
        end)

        Table.print(
          headers: ["Name", "Adapter", "Base URL", "Active"],
          rows: rows,
          table_border: :rounded,
          headers_color: :cyan
        )
    end
  end

  defp handle_engine(["delete" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.EngineManager.delete_engine(name) do
        :ok ->
          IO.puts("✅ Motor '#{name}' eliminado exitosamente")

        {:error, reason} ->
          IO.puts("❌ Error al eliminar motor: #{reason}")
      end
    else
      IO.puts("❌ Error: Falta --name")
    end
  end

  defp handle_engine(["update" | rest]) do
    name = get_opt(rest, :name)

    if name do
      # Parse options from command line arguments
      attrs = %{
        active: get_opt(rest, :active),
        timeout: get_opt(rest, :timeout) |> parse_int()
      }

      # Filter out nil values
      attrs = Enum.filter(attrs, fn {_, val} -> val != nil end) |> Map.new()

      case ElPaso.Domain.EngineManager.update_engine(name, attrs) do
        {:ok, _engine} ->
          IO.puts("✅ Motor '#{name}' actualizado exitosamente")

        {:error, reason} ->
          IO.puts("❌ Error al actualizar motor: #{reason}")
      end
    else
      IO.puts("❌ Error: Falta --name")
    end
  end

  defp handle_engine(["show" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.EngineManager.list_engines() |> Enum.find(&(&1.name == name)) do
        nil ->
          IO.puts("❌ Motor no encontrado")

        engine ->
          IO.puts("Motor: #{engine.name}")
          IO.puts("  Adapter: #{engine.adapter}")
          IO.puts("  Base URL: #{engine.base_url}")
          IO.puts("  Active: #{engine.active}")
      end
    else
      IO.puts("❌ Error: Falta --name")
    end
  end

  defp handle_engine(["add" | rest]) do
    # Parse options from command line arguments
    name = get_opt(rest, :name)
    adapter = get_opt(rest, :adapter)
    base_url = get_opt(rest, :base_url) || get_opt(rest, :url)

    if name && adapter && base_url do
      attrs = %{
        name: name,
        adapter: adapter,
        base_url: base_url,
        api_key: get_opt(rest, :api_key),
        description: get_opt(rest, :description),
        active: get_opt(rest, :active) || true,
        timeout: get_opt(rest, :timeout) |> parse_int()
      }

      case ElPaso.Domain.EngineManager.create_engine(attrs) do
        {:ok, _engine} ->
          IO.puts("✅ Motor '#{name}' creado exitosamente")

        {:error, reason} ->
          IO.puts("❌ Error al crear motor: #{reason}")
      end
    else
      IO.puts("❌ Error: Faltan parámetros requeridos")

      IO.puts(
        "Uso: elpaso engine add --name <name> --adapter <adapter> --base-url <url> [opciones]"
      )
    end
  end

  defp handle_engine(["test" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.EngineManager.test_engine(name) do
        :ok ->
          IO.puts("✅ Motor '#{name}' conectividad verificada exitosamente")

        {:error, reason} ->
          IO.puts("❌ Error al verificar conectividad: #{reason}")
      end
    else
      IO.puts("❌ Error: Falta --name")
      IO.puts("Uso: elpaso engine test --name <nombre>")
    end
  end

  defp handle_engine([]) do
    handle_engine(["list"])
  end

  defp handle_engine(args) do
    handle_engine(["add" | args])
  end

  # ==================== HELPERS ====================

  defp get_opt(args, key) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          name: :string,
          adapter: :string,
          base_url: :string,
          url: :string,
          api_key: :string,
          description: :string,
          active: :boolean,
          engine: :string,
          max_tokens: :integer,
          temp: :float,
          temperature: :float,
          top_p: :float,
          timeout: :integer,
          model: :string,
          personality: :string,
          system_prompt: :string,
          prompt: :string,
          concurrency: :integer,
          duration: :integer,
          models: :string,
          task: :string,
          limit: :integer,
          env: :string,
          port: :integer,
          log_level: :string,
          key: :string,
          revert_auto: :boolean,
          session: :string,
          all: :boolean,
          user: :string,
          discovery: :string,
          nodes: :string,
          node: :string
        ]
      )

    opts[key]
  end

  defp parse_int(value) when is_binary(value), do: String.to_integer(value)
  defp parse_int(nil), do: nil

  defp parse_float(value) when is_binary(value), do: String.to_float(value)
  defp parse_float(nil), do: nil

  defp handle_config(["show" | _]) do
    config = ElPaso.Config.Loader.load_config_file()

    if config == %{} do
      IO.puts("ℹ️  No hay configuración. Ejecuta: elpaso init")
    else
      IO.puts("Configuración (~/.config/elpaso/elpaso.conf):")

      Enum.each(config, fn {section, values} ->
        IO.puts("")
        IO.puts("[#{section}]")

        Enum.each(values, fn {key, value} ->
          IO.puts("  #{key} = #{value}")
        end)
      end)
    end
  end

  defp handle_config(["set" | rest]) do
    {opts, _, _} =
      OptionParser.parse(rest,
        switches: [
          section: :string,
          key: :string,
          value: :string
        ]
      )

    section = Keyword.get(opts, :section)
    key = Keyword.get(opts, :key)
    value = Keyword.get(opts, :value)

    if section && key && value do
      config = ElPaso.Config.Loader.load_config_file()
      section_map = Map.get(config, section, %{})
      updated_section = Map.put(section_map, key, value)
      updated_config = Map.put(config, section, updated_section)
      ElPaso.Config.Loader.save_config_file(updated_config)
      IO.puts("✅ #{section}.#{key} = #{value}")
    else
      IO.puts("❌ Faltan parámetros")
      IO.puts("Uso: elpaso config set --section <s> --key <k> --value <v>")
    end
  end

  defp handle_config(["reload" | _]) do
    IO.puts("Recargando configuración...")
    _ = ElPaso.Config.Loader.load_config_file()
    IO.puts("✅ Configuración recargada")
  end

  defp handle_config([]) do
    IO.puts("Usa 'elpaso config --help' para ver ayuda del comando config.")
  end

  defp handle_router(["stats" | rest]) do
    {opts, _, _} = OptionParser.parse(rest, switches: [limit: :integer])
    limit = Keyword.get(opts, :limit, 20)

    try do
      decisions = ElPaso.Context.Storage.query_routing_decisions(limit: limit)

      if decisions == [] do
        IO.puts("ℹ️  No hay decisiones de routing registradas")
      else
        rows = Enum.map(decisions, fn d ->
          lat = if d.decision_latency_us, do: "#{d.decision_latency_us}µs", else: "N/A"
          [d.request_id, d.selected_model, d.reason, lat]
        end)

        Table.print(
          headers: ["Request ID", "Modelo", "Razón", "Latencia"],
          rows: rows,
          table_border: :rounded,
          headers_color: :cyan
        )
      end
    rescue
      _ ->
        IO.puts("ℹ️  No hay estadísticas de routing disponibles")
    end
  end

  defp handle_router(["tune" | _]) do
    try do
      ElPaso.Domain.AutoTuner.run_now()
      IO.puts("✅ Auto-tuneo completado")
    rescue
      _ ->
        IO.puts("⚠️  Auto-tuneo no disponible en este momento")
    end
  end

  defp handle_router(["rules" | _]) do
    try do
      states = ElPaso.Domain.ModelManager.all_states()

      if states == [] do
        IO.puts("ℹ️  No hay reglas de routing activas")
      else
        rows = Enum.map(states, fn s ->
          [s.model_id, to_string(s.status), to_string(s.current_queue_depth), "#{s.avg_latency_ms}ms"]
        end)

        Table.print(
          headers: ["Modelo", "Estado", "Cola", "Latencia media"],
          rows: rows,
          table_border: :rounded,
          headers_color: :cyan
        )
      end
    rescue
      _ ->
        IO.puts("⚠️  No se pudieron cargar las reglas de routing")
    end
  end

  defp handle_router([]) do
    IO.puts("Usa 'elpaso router --help' para ver ayuda del comando router.")
  end

  defp handle_bench(["run" | rest]) do
    {opts, _, _} =
      OptionParser.parse(rest,
        switches: [
          models: :string,
          prompt: :string,
          concurrency: :integer,
          duration: :integer
        ]
      )

    models =
      case Keyword.get(opts, :models) do
        nil -> Enum.map(ElPaso.Domain.ModelManager.list_models(), & &1.name)
        s -> String.split(s, ",")
      end

    prompt = Keyword.get(opts, :prompt, "Explain quantum computing in simple terms")
    concurrency = Keyword.get(opts, :concurrency, 1)
    duration = Keyword.get(opts, :duration, 10)

    IO.puts("Benchmark:")
    IO.puts("  Modelos: #{Enum.join(models, ", ")}")
    IO.puts("  Prompt: #{prompt}")
    IO.puts("  Concurrencia: #{concurrency}")
    IO.puts("  Duración: #{duration}s")
    IO.puts("")

    Enum.each(models, fn model ->
      IO.puts("Testeando #{model}...")

      {time_us, result} =
        :timer.tc(fn ->
          ElPaso.Domain.ModelManager.infer(model, %{messages: [%{role: "user", content: prompt}]})
        end)

      case result do
        {:ok, resp} ->
          tokens = Map.get(resp, :completion_tokens, 0)
          tps = if time_us > 0, do: Float.round(tokens / (time_us / 1_000_000), 1), else: 0
          IO.puts("  ✅ #{time_us / 1000}ms | #{tokens} tokens | #{tps} tok/s")

        {:error, reason} ->
          IO.puts("  ❌ Error: #{inspect(reason)}")
      end
    end)
  end

  defp handle_bench([]) do
    IO.puts("Usa 'elpaso bench --help' para ver ayuda del comando bench.")
  end

  defp handle_context(["list" | rest]) do
    {opts, _, _} = OptionParser.parse(rest, switches: [limit: :integer, user: :string])
    limit = Keyword.get(opts, :limit, 50)

    sessions = ElPaso.Context.Storage.list_sessions() |> Enum.take(limit)

    if sessions == [] do
      IO.puts("No hay sesiones registradas")
    else
      rows = Enum.map(sessions, fn s ->
        user = s.user_id || "anon"
        created = s.created_at || "N/A"
        [s.id, user, to_string(created)]
      end)

      Table.print(
        headers: ["ID", "Usuario", "Creada"],
        rows: rows,
        table_border: :rounded,
        headers_color: :cyan
      )
    end
  end

  defp handle_context(["show" | rest]) do
    id = get_opt(rest, :session) || List.first(rest)

    if id do
      case ElPaso.Context.Storage.get_session(id) do
        nil ->
          IO.puts("❌ Sesión no encontrada: #{id}")

        session ->
          IO.puts("Sesión: #{session.id}")
          IO.puts("  Usuario: #{session.user_id || "anon"}")
          IO.puts("  Creada: #{session.created_at}")
          IO.puts("  Actualizada: #{session.updated_at}")

          messages = ElPaso.Context.Storage.get_all_messages(session.id)
          IO.puts("  Mensajes: #{length(messages)}")

          Enum.each(messages, fn m ->
            IO.puts("    [#{m.role}] #{String.slice(m.content, 0, 60)}...")
          end)
      end
    else
      IO.puts("❌ Falta ID de sesión")
      IO.puts("Uso: elpaso context show <session_id>")
    end
  end

  defp handle_context(["clear" | rest]) do
    {opts, _, _} = OptionParser.parse(rest, switches: [all: :boolean, session: :string])

    cond do
      Keyword.get(opts, :all) ->
        # No hay función para borrar todo en Storage, usamos truncate vía Repo
        Ecto.Adapters.SQL.query!(ElPaso.Repo, "TRUNCATE sessions, messages CASCADE")
        IO.puts("✅ Todas las sesiones y mensajes eliminados")

      id = Keyword.get(opts, :session) ->
        ElPaso.Context.Storage.delete_session(id)
        IO.puts("✅ Sesión #{id} eliminada")

      true ->
        IO.puts("❌ Especifica --all o --session <id>")
    end
  end

  defp handle_context([]) do
    IO.puts("Usa 'elpaso context --help' para ver ayuda del comando context.")
  end

  defp handle_cluster(["status" | _]) do
    try do
      nodes = ElPaso.Cluster.NodeRegistry.all_nodes()

      if nodes == [] do
        IO.puts("🔴 Sin nodos en el cluster")
      else
        IO.puts("🟢 Cluster activo")
        IO.puts("  Nodos: #{length(nodes)}")
        Enum.each(nodes, fn n -> IO.puts("    • #{n}") end)
      end
    rescue
      _ ->
        IO.puts("ℹ️  Cluster no configurado. Habilita en ~/.config/elpaso/elpaso.conf")
    end
  end

  defp handle_cluster(["nodes" | _]) do
    try do
      nodes = ElPaso.Cluster.NodeRegistry.all_nodes()

      if nodes == [] do
        IO.puts("No hay nodos registrados")
      else
        rows = Enum.map(nodes, fn n ->
          alive = if Node.ping(String.to_atom(n)) == :pong, do: "🟢 vivo", else: "🔴 caído"
          [to_string(n), alive]
        end)

        Table.print(
          headers: ["Nodo", "Estado"],
          rows: rows,
          table_border: :rounded,
          headers_color: :cyan
        )
      end
    rescue
      _ ->
        IO.puts("ℹ️  Cluster no disponible")
    end
  end

  defp handle_cluster(["join" | rest]) do
    {opts, _, _} = OptionParser.parse(rest, switches: [nodes: :string, discovery: :string])

    case Keyword.get(opts, :nodes) do
      nil ->
        IO.puts("❌ Especifica --nodes ip1,ip2")

      nodes_str ->
        nodes = String.split(nodes_str, ",")

        Enum.each(nodes, fn n ->
          node_atom = String.to_atom("elpaso@#{n}")
          Node.connect(node_atom)
          IO.puts("🔗 Conectando a #{node_atom}...")
        end)

        IO.puts("✅ Conectado a #{length(nodes)} nodo(s)")
    end
  end

  defp handle_cluster([]) do
    IO.puts("Usa 'elpaso cluster --help' para ver ayuda del comando cluster.")
  end

  # ==================== PERSONALITY HANDLERS ====================

  defp handle_personality(["add" | rest]) do
    name = get_opt(rest, :name)
    description = get_opt(rest, :description)
    system_prompt = get_opt(rest, :system_prompt)

    if name && system_prompt do
      attrs = %{
        name: name,
        description: description,
        system_prompt: system_prompt
      }

      case ElPaso.Domain.PersonalityManager.create_personality(attrs) do
        {:ok, _personality} ->
          IO.puts("✅ Personalidad '#{name}' creada exitosamente")

        {:error, reason} ->
          IO.puts("❌ Error al crear personalidad: #{reason}")
      end
    else
      IO.puts("❌ Error: Faltan parámetros requeridos")
      IO.puts("Uso: elpaso personality add --name <nombre> --system-prompt <prompt>")
    end
  end

  defp handle_personality(["list" | _]) do
    personalities = ElPaso.Domain.PersonalityManager.list_personalities()

    if Enum.empty?(personalities) do
      IO.puts("No hay personalidades registradas")
    else
      rows = Enum.map(personalities, fn p ->
        desc = p.description || "N/A"
        prompt = String.slice(p.system_prompt, 0, 30) <> "..."
        [p.name, desc, prompt]
      end)

      Table.print(
        headers: ["Nombre", "Descripción", "System Prompt"],
        rows: rows,
        table_border: :rounded,
        headers_color: :cyan
      )
    end
  end

  defp handle_personality(["delete" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.PersonalityManager.delete_personality(name) do
        {:ok, _} ->
          IO.puts("✅ Personalidad '#{name}' eliminada exitosamente")

        {:error, reason} ->
          IO.puts("❌ Error al eliminar personalidad: #{reason}")
      end
    else
      IO.puts("❌ Error: Falta --name")
    end
  end

  defp handle_personality(["show" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.PersonalityManager.get_personality(name) do
        nil ->
          IO.puts("❌ Personalidad no encontrada")

        personality ->
          IO.puts("Personalidad: #{personality.name}")
          IO.puts("  Descripción: #{personality.description || "N/A"}")
          IO.puts("  System Prompt: #{personality.system_prompt}")
      end
    else
      IO.puts("❌ Error: Falta --name")
    end
  end

  defp handle_personality(["use" | rest]) do
    model_name = get_opt(rest, :model)
    personality_name = get_opt(rest, :personality)

    if model_name && personality_name do
      # This would be implemented in the future to assign personality to model
      IO.puts("✅ Personalidad '#{personality_name}' asignada al modelo '#{model_name}'")
    else
      IO.puts("❌ Error: Faltan parámetros requeridos")
      IO.puts("Uso: elpaso personality use --model <modelo> --personality <nombre>")
    end
  end

  defp handle_personality([]) do
    IO.puts("Usa 'elpaso personality --help' para ver ayuda.")
  end

  defp handle_personality(args) do
    handle_personality(["list" | args])
  end

  # ==================== PROFILE HANDLERS ====================

  defp handle_profile(["add" | rest]) do
    name = get_opt(rest, :name)
    model_name = get_opt(rest, :model)
    engine_name = get_opt(rest, :engine)
    personality_name = get_opt(rest, :personality)

    if name && model_name && engine_name && personality_name do
      # Get the IDs from the database
      model = ElPaso.Domain.ModelManager.get_model(model_name)
      engine = ElPaso.Domain.EngineManager.get_engine(engine_name)
      personality = ElPaso.Domain.PersonalityManager.get_personality(personality_name)

      if model && engine && personality do
        attrs = %{
          name: name,
          model_id: model.id,
          engine_id: engine.id,
          personality_id: personality.id
        }

        case ElPaso.Domain.ProfileManager.create_profile(attrs) do
          {:ok, _profile} ->
            IO.puts("✅ Profile '#{name}' creado exitosamente")

          {:error, reason} ->
            IO.puts("❌ Error al crear profile: #{reason}")
        end
      else
        IO.puts("❌ Error: Uno o más elementos no encontrados (modelo, motor o personalidad)")
      end
    else
      IO.puts("❌ Error: Faltan parámetros requeridos")

      IO.puts(
        "Uso: elpaso profile add --name <nombre> --model <modelo> --engine <motor> --personality <personalidad>"
      )
    end
  end

  defp handle_profile(["list" | _]) do
    profiles = ElPaso.Domain.ProfileManager.list_profiles()

    if Enum.empty?(profiles) do
      IO.puts("No hay profiles registrados")
    else
      rows = Enum.map(profiles, fn p ->
        [p.name, p.model.name, p.engine.name, p.personality.name]
      end)

      Table.print(
        headers: ["Nombre", "Modelo", "Motor", "Personalidad"],
        rows: rows,
        table_border: :rounded,
        headers_color: :cyan
      )
    end
  end

  defp handle_profile(["delete" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.ProfileManager.delete_profile(name) do
        {:ok, _} ->
          IO.puts("✅ Profile '#{name}' eliminado exitosamente")

        {:error, reason} ->
          IO.puts("❌ Error al eliminar profile: #{reason}")
      end
    else
      IO.puts("❌ Error: Falta --name")
    end
  end

  defp handle_profile(["show" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.ProfileManager.get_profile(name) do
        nil ->
          IO.puts("❌ Profile no encontrado")

        profile ->
          IO.puts("Profile: #{profile.name}")
          IO.puts("  Modelo: #{profile.model.name}")
          IO.puts("  Motor: #{profile.engine.name}")
          IO.puts("  Personalidad: #{profile.personality.name}")
      end
    else
      IO.puts("❌ Error: Falta --name")
    end
  end

  defp handle_profile([]) do
    IO.puts("Usa 'elpaso profile --help' para ver ayuda.")
  end

  defp handle_profile(args) do
    handle_profile(["list" | args])
  end

  # ==================== SERVER HANDLERS ====================

  defp handle_server(["start" | rest]) do
    {opts, _, _} =
      OptionParser.parse(rest,
        switches: [
          port: :integer,
          bind: :string
        ]
      )

    port = Keyword.get(opts, :port, 8080)

    if port != 8080 do
      Application.put_env(:elpaso, :http_port, port)
    end

    Header.print("ElPaso v0.1.0", subtitle: "Multi-Model LLM Proxy")
    IO.puts("")
    IO.puts("[init] Arrancando aplicación OTP...")

    case Application.ensure_all_started(:elpaso) do
      {:ok, _} ->
        IO.puts("[init] ✅ Aplicación OTP lista")
        IO.puts("")
        IO.puts("Endpoint HTTP:    http://0.0.0.0:#{port}")
        IO.puts("Dashboard:        http://0.0.0.0:#{port}/dashboard")
        IO.puts("Métricas:         http://0.0.0.0:#{port}/metrics")
        IO.puts("API Anthropic:    POST http://0.0.0.0:#{port}/v1/messages")
        IO.puts("")

        try do
          engines = ElPaso.Domain.EngineManager.list_engines()
          models = ElPaso.Domain.ModelManager.list_models()

          if engines != [] do
            IO.puts("Engines registrados:")

            Enum.each(engines, fn e ->
              IO.puts("  • #{e.name} (#{e.adapter}) → #{e.base_url}")
            end)
          else
            IO.puts("⚠️  No hay engines registrados. Usa: elpaso engine add ...")
          end

          IO.puts("")

          if models != [] do
            IO.puts("Modelos registrados:")

            Enum.each(models, fn m ->
              IO.puts("  • #{m.name} → #{m.url}")
            end)
          else
            IO.puts("⚠️  No hay modelos registrados. Usa: elpaso model add ...")
          end
        rescue
          _ -> :ok
        end

        IO.puts("")
        IO.puts("Presiona Ctrl+C para detener")
        IO.puts("")

        receive do
        after
          :infinity -> :ok
        end

      {:error, {app, reason}} ->
        IO.puts("[init] ❌ Error al iniciar #{app}: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp handle_server(["stop" | _]) do
    case Application.stop(:elpaso) do
      :ok ->
        IO.puts("✅ Servidor detenido")

      {:error, {:not_started, :elpaso}} ->
        IO.puts("ℹ️  ElPaso no está en ejecución")
    end
  end

  defp handle_server(["restart" | _]) do
    IO.puts("[init] Reiniciando ElPaso...")
    Application.stop(:elpaso)

    case Application.ensure_all_started(:elpaso) do
      {:ok, _} ->
        port = ElPaso.Config.http_port()
        IO.puts("[init] ✅ Reiniciado en http://0.0.0.0:#{port}")

      {:error, {app, reason}} ->
        IO.puts("[init] ❌ Error al reiniciar #{app}: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp handle_server(["status" | _]) do
    case Application.started_applications() |> Enum.find(&(elem(&1, 0) == :elpaso)) do
      nil ->
        IO.puts("🔴 Detenido")

      _ ->
        port = ElPaso.Config.http_port()
        IO.puts("🟢 Activo en http://localhost:#{port}")
    end
  end

  defp handle_server(["log" | rest]) do
    {opts, _, _} =
      OptionParser.parse(rest,
        switches: [
          lines: :integer
        ]
      )

    lines = Keyword.get(opts, :lines, 100)
    log_path = "log/elpaso.log"

    if File.exists?(log_path) do
      File.stream!(log_path)
      |> Enum.take(-lines)
      |> Enum.each(&IO.write/1)
    else
      IO.puts("ℹ️  No se encontró #{log_path}. Los logs van a stdout.")
    end
  end

  defp handle_server([]) do
    IO.puts("Usa 'elpaso server --help' para ver ayuda.")
  end

  defp handle_server(args) do
    handle_server(["status" | args])
  end
end
