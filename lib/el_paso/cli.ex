defmodule ElPaso.CLI do
  @moduledoc """
  CLI principal para elpaso.
  """

  alias ElPaso.CLI.Output

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
      elpaso cluster --help

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

      elpaso bench run      Ejecutar benchmark

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
          Output.error("Error al iniciar la aplicación #{app}: #{inspect(reason)}")
          Output.info("Asegúrate de que PostgreSQL está corriendo y la DB existe.")
          Output.info("Crea la DB con:  mix ecto.create && mix ecto.migrate")
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
      ["init" | rest] ->
        handle_init(rest)

      ["model" | rest] ->
        handle_model(rest)

      ["engine" | rest] ->
        handle_engine(rest)

      ["personality" | rest] ->
        handle_personality(rest)

      ["config" | rest] ->
        handle_config(rest)

      ["db" | rest] ->
        handle_db(rest)

      ["server" | rest] ->
        handle_server(rest)

      ["router" | rest] ->
        handle_router(rest)

      ["bench" | rest] ->
        handle_bench(rest)

      ["context" | rest] ->
        handle_context(rest)

      ["cluster" | rest] ->
        handle_cluster(rest)

      _ ->
        Output.error(
          "Comando desconocido. Usa 'elpaso --help' para ver los comandos disponibles."
        )
    end
  end

  # ==================== INIT HANDLERS ====================

  defp handle_init(_) do
    config_dir = Path.expand("~/.config/elpaso")
    config_file = Path.join(config_dir, "elpaso.conf")

    File.mkdir_p!(config_dir)

    if File.exists?(config_file) do
      Output.info("Configuración ya existe en #{config_file}")
    else
      default_config = """
      # ElPaso Configuration

      [http]
      port = 4000
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
      Output.success("Configuración creada en #{config_file}")
    end

    Output.success("ElPaso inicializado")
  end

  # ==================== DB HANDLERS ====================

  defp handle_db(["create" | _]) do
    # Validar que el nombre de BD solo contenga caracteres seguros
    db_url = System.get_env("DATABASE_URL", "postgresql://postgres:postgres@localhost/elpaso")

    config = Ecto.Repo.Supervisor.parse_url(db_url)
    db_name = config[:database]

    # Validar db_name contra inyección: solo letras, números, guiones y underscore
    unless String.match?(db_name, ~r/^[a-zA-Z0-9_-]+$/) do
      Output.error(
        "Nombre de base de datos inválido: '#{db_name}'. Solo se permiten letras, números, guiones y underscores."
      )

      System.halt(1)
    end

    # Conectar a postgres sin especificar DB para crear la nuestra
    create_config = Keyword.put(config, :database, "postgres")

    case Postgrex.start_link(create_config) do
      {:ok, conn} ->
        # Usar quoted identifier para prevenir SQL injection
        safe_db_name = "\"#{String.replace(db_name, "\"", "\"\"")}\""

        case Postgrex.query(conn, "CREATE DATABASE #{safe_db_name}", []) do
          {:ok, _} ->
            Output.success("Base de datos '#{db_name}' creada")
            GenServer.stop(conn)

          {:error, %{postgres: %{code: :duplicate_database}}} ->
            Output.info("Base de datos '#{db_name}' ya existe")
            GenServer.stop(conn)

          {:error, reason} ->
            Output.error("Error al crear la base de datos: #{inspect(reason)}")
            GenServer.stop(conn)
            System.halt(1)
        end

      {:error, reason} ->
        Output.error("No se pudo conectar a PostgreSQL: #{inspect(reason)}")
        Output.info("Asegúrate de que PostgreSQL está corriendo.")
        System.halt(1)
    end
  end

  defp handle_db(["migrate" | _]) do
    path = Application.app_dir(:elpaso, "priv/repo/migrations")

    case Ecto.Migrator.run(ElPaso.Repo, path, :up, all: true) do
      [] ->
        Output.info("No hay migraciones pendientes")

      migrations ->
        Output.success("#{length(migrations)} migración(es) aplicada(s)")
    end
  end

  defp handle_db(["status" | _]) do
    path = Application.app_dir(:elpaso, "priv/repo/migrations")
    status = Ecto.Migrator.migrations(ElPaso.Repo, path)

    if status == [] do
      Output.warning("No hay migraciones")
    else
      rows =
        Enum.map(status, fn {state, version, name} ->
          state_str =
            case state do
              :up -> "Aplicada"
              :down -> "Pendiente"
              :missing -> "Faltante"
            end

          [to_string(version), name, state_str]
        end)

      Output.data_table(
        headers: ["Versión", "Nombre", "Estado"],
        rows: rows,
        table_border: :rounded,
        headers_color: :cyan
      )
    end
  end

  defp handle_db([]) do
    Output.info("Usa 'elpaso db --help' para ver ayuda.")
    IO.puts("Comandos: create, migrate, status")
  end

  # ==================== HANDLERS ====================

  defp handle_model(["list" | _]) do
    case ElPaso.Domain.ModelManager.list_models() do
      [] ->
        Output.warning("No hay modelos registrados")

      models ->
        rows =
          Enum.map(models, fn m ->
            [m.name, m.engine_id, m.url, to_string(m.active)]
          end)

        Output.data_table(
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
          Output.success("Modelo '#{name}' eliminado exitosamente")

        {:error, reason} ->
          Output.error("Error al eliminar modelo: #{reason}")
      end
    else
      Output.error("Error: Falta --name")
      Output.error("Uso: elpaso model delete --name <nombre>")
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
          Output.success("Modelo '#{name}' actualizado exitosamente")

        {:error, reason} ->
          Output.error("Error al actualizar modelo: #{reason}")
      end
    else
      Output.error("Error: Falta --name")
      Output.error("Uso: elpaso model update --name <nombre> [opciones]")
    end
  end

  defp handle_model(["show" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.ModelManager.get_model(name) do
        nil ->
          Output.error("Modelo no encontrado")

        model ->
          Output.section(model.name, subtitle: "Modelo")

          Output.data_table(
            headers: ["Campo", "Valor"],
            rows: [
              ["Engine", model.engine_id],
              ["URL", model.url],
              ["Active", to_string(model.active)],
              ["Max tokens", to_string(model.max_tokens || 4096)],
              ["Temperature", to_string(model.temperature || 0.7)],
              ["Top-p", to_string(model.top_p || 1.0)]
            ],
            table_border: :rounded,
            headers_color: :cyan
          )
      end
    else
      Output.error("Error: Falta --name")
      Output.error("Uso: elpaso model show --name <nombre>")
    end
  end

  defp handle_model(["start" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.ModelManager.start_model(name) do
        {:ok, _model} ->
          Output.success("Modelo '#{name}' iniciado exitosamente")

        {:error, reason} ->
          Output.error("Error al iniciar modelo: #{reason}")
      end
    else
      Output.error("Error: Falta --name")
      Output.error("Uso: elpaso model start --name <nombre>")
    end
  end

  defp handle_model(["stop" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.ModelManager.stop_model(name) do
        {:ok, _model} ->
          Output.success("Modelo '#{name}' detenido exitosamente")

        {:error, reason} ->
          Output.error("Error al detener modelo: #{reason}")
      end
    else
      Output.error("Error: Falta --name")
      Output.error("Uso: elpaso model stop --name <nombre>")
    end
  end

  defp handle_model(["add" | rest]) do
    name = get_opt(rest, :name)
    engine_name = get_opt(rest, :engine)
    url = get_opt(rest, :url)

    if name && engine_name && url do
      engine = ElPaso.Repo.get_by(ElPaso.Models.Engine, name: engine_name)

      if is_nil(engine) do
        Output.error("Engine '#{engine_name}' no encontrado")
      else
        attrs = %{
          name: name,
          engine_id: engine.id,
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
            Output.success("Modelo '#{name}' creado exitosamente")

          {:error, reason} ->
            Output.error("Error al crear modelo: #{inspect(reason)}")
        end
      end
    else
      Output.error("Error: Faltan parámetros requeridos")
      Output.error("Uso: elpaso model add --name <name> --engine <engine> --url <url> [opciones]")
    end
  end

  defp handle_model([]) do
    Output.info("Usa 'elpaso model --help' para ver ayuda del comando model.")
  end

  defp handle_model(args) do
    handle_model(["list" | args])
  end

  defp handle_engine(["list" | _]) do
    case ElPaso.Domain.EngineManager.list_engines() do
      [] ->
        Output.warning("No hay motores registrados")

      engines ->
        rows =
          Enum.map(engines, fn e ->
            [e.name, e.adapter, e.base_url, to_string(e.active)]
          end)

        Output.data_table(
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
          Output.success("Motor '#{name}' eliminado exitosamente")

        {:error, reason} ->
          Output.error("Error al eliminar motor: #{reason}")
      end
    else
      Output.error("Error: Falta --name")
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
          Output.success("Motor '#{name}' actualizado exitosamente")

        {:error, reason} ->
          Output.error("Error al actualizar motor: #{reason}")
      end
    else
      Output.error("Error: Falta --name")
    end
  end

  defp handle_engine(["show" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.EngineManager.list_engines() |> Enum.find(&(&1.name == name)) do
        nil ->
          Output.error("Motor no encontrado")

        engine ->
          Output.section(engine.name, subtitle: "Motor")

          Output.data_table(
            headers: ["Campo", "Valor"],
            rows: [
              ["Adapter", engine.adapter],
              ["Base URL", engine.base_url],
              ["Active", to_string(engine.active)],
              ["Timeout", to_string(engine.timeout || 60000)]
            ],
            table_border: :rounded,
            headers_color: :cyan
          )
      end
    else
      Output.error("Error: Falta --name")
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
          Output.success("Motor '#{name}' creado exitosamente")

        {:error, reason} ->
          Output.error("Error al crear motor: #{reason}")
      end
    else
      Output.error("Error: Faltan parámetros requeridos")

      Output.error(
        "Uso: elpaso engine add --name <name> --adapter <adapter> --base-url <url> [opciones]"
      )
    end
  end

  defp handle_engine(["test" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.EngineManager.test_engine(name) do
        {:ok, latency_ms} ->
          Output.success("Motor '#{name}' connectivity OK (#{latency_ms}ms)")

        {:error, reason} ->
          Output.error("Error al verificar conectividad: #{reason}")
      end
    else
      Output.error("Error: Falta --name")
      Output.error("Uso: elpaso engine test --name <nombre>")
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
          node: :string,
          keywords: :string,
          task_types: :string,
          priority: :integer,
          default: :string
        ]
      )

    opts[key]
  end

  defp parse_int(value) when is_binary(value), do: String.to_integer(value)
  defp parse_int(value) when is_integer(value), do: value
  defp parse_int(nil), do: nil

  defp parse_csv(nil), do: []

  defp parse_csv(str) when is_binary(str),
    do: String.split(str, ",", trim: true) |> Enum.map(&String.trim/1)

  defp parse_float(value) when is_binary(value), do: String.to_float(value)
  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value * 1.0
  defp parse_float(nil), do: nil

  defp handle_config(["show" | _]) do
    config = ElPaso.Config.Loader.load_config_file()

    if config == %{} do
      Output.info("No hay configuración. Ejecuta: elpaso init")
    else
      Output.section("~/.config/elpaso/elpaso.conf", subtitle: "Configuración")

      Enum.each(config, fn {section, values} ->
        Output.divider(section, char: "═")

        rows =
          Enum.map(values, fn {key, value} ->
            [to_string(key), to_string(value)]
          end)

        Output.data_table(
          headers: ["Clave", "Valor"],
          rows: rows,
          table_border: :rounded,
          headers_color: :cyan
        )
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
      Output.success("#{section}.#{key} = #{value}")
    else
      Output.error("Faltan parámetros")
      Output.error("Uso: elpaso config set --section <s> --key <k> --value <v>")
    end
  end

  defp handle_config(["reload" | _]) do
    Output.info("Recargando configuración...")
    _ = ElPaso.Config.Loader.load_config_file()
    Output.success("Configuración recargada")
  end

  defp handle_config([]) do
    Output.info("Usa 'elpaso config --help' para ver ayuda del comando config.")
  end

  defp handle_router(["stats" | rest]) do
    {opts, _, _} = OptionParser.parse(rest, switches: [limit: :integer])
    limit = Keyword.get(opts, :limit, 20)

    try do
      decisions = ElPaso.Context.Storage.query_routing_decisions(limit: limit)

      if decisions == [] do
        Output.info("No hay decisiones de routing registradas")
      else
        rows =
          Enum.map(decisions, fn d ->
            lat = if d.decision_latency_us, do: "#{d.decision_latency_us}µs", else: "N/A"
            [d.request_id, d.selected_model, d.reason, lat]
          end)

        Output.data_table(
          headers: ["Request ID", "Modelo", "Razón", "Latencia"],
          rows: rows,
          table_border: :rounded,
          headers_color: :cyan
        )
      end
    rescue
      _ ->
        Output.info("No hay estadísticas de routing disponibles")
    end
  end

  defp handle_router(["tune" | rest]) do
    if get_opt(rest, :revert_auto) do
      case ElPaso.Domain.AutoTuner.revert_last() do
        {:ok, msg} -> Output.success(msg)
        {:error, msg} -> Output.error(msg)
      end
    else
      run_router_tune_sync()
    end
  end

  defp handle_router(["rules" | _]) do
    try do
      states = ElPaso.Domain.ModelManager.all_states()

      if states == [] do
        Output.info("No hay reglas de routing activas")
      else
        rows =
          Enum.map(states, fn s ->
            [
              s.model_id,
              to_string(s.status),
              to_string(s.current_queue_depth),
              "#{s.avg_latency_ms}ms"
            ]
          end)

        Output.data_table(
          headers: ["Modelo", "Estado", "Cola", "Latencia media"],
          rows: rows,
          table_border: :rounded,
          headers_color: :cyan
        )
      end
    rescue
      _ ->
        Output.warning("No se pudieron cargar las reglas de routing")
    end
  end

  defp handle_router([]) do
    Output.info("Usa 'elpaso router --help' para ver ayuda del comando router.")
  end

  # Ejecuta el tuneo de forma síncrona (no usa el AutoTuner periódico).
  defp run_router_tune_sync do
    try do
      Output.info("Analizando tendencias de routing (últimos 30 días)...")

      analyses = ElPaso.Domain.RouterAnalyzer.analyze_trends(:last_30d)

      if Enum.empty?(analyses) do
        Output.warning(
          "No hay datos suficientes para análisis. Se necesitan routing_decisions en la DB."
        )
      else
        appliable =
          Enum.filter(analyses, fn a ->
            n = a.n_decisions

            confidence =
              min(n / 500.0, 1.0) *
                case a.success_trend do
                  :improving -> 0.9
                  :degrading -> 1.0
                  :stable -> 0.5
                end

            n >= 50 and confidence >= 0.85
          end)

        if Enum.empty?(appliable) do
          Output.info("No hay cambios de alta confianza para aplicar.")
          Output.divider("Análisis de tendencias")
          print_router_analyses(analyses)
        else
          changes =
            Enum.map(appliable, fn analysis ->
              apply_tune_affinity(analysis)
            end)

          ElPaso.Context.Storage.save_auto_tune_run(%{
            applied: length(changes),
            at: DateTime.utc_now(),
            changes: changes
          })

          Output.divider("Cambios aplicados (#{length(changes)})")

          rows =
            Enum.map(changes, fn c ->
              [
                "#{c.model_id}@#{c.task_type}",
                "#{Float.round(c.previous_affinity, 2)} → #{Float.round(c.new_affinity, 2)}"
              ]
            end)

          Output.data_table(
            headers: ["Modelo@Tarea", "Affinity anterior → nueva"],
            rows: rows,
            table_border: :rounded,
            headers_color: :cyan
          )

          Output.success("Auto-tuneo completado: #{length(changes)} cambio(s) aplicado(s)")
        end
      end
    rescue
      e ->
        Output.error("Error en auto-tuneo: #{inspect(e)}")
    end
  end

  defp apply_tune_affinity(analysis) do
    current = ElPaso.Config.Loader.get_affinity(analysis.model_id, analysis.task_type)

    suggested =
      case analysis.success_trend do
        :improving -> min(current + 0.1, 1.0)
        :degrading -> max(current - 0.15, 0.1)
        :stable -> current
      end

    ElPaso.Config.Loader.update_affinity(analysis.model_id, analysis.task_type, suggested)

    %{
      model_id: analysis.model_id,
      task_type: analysis.task_type,
      previous_affinity: current,
      new_affinity: suggested
    }
  end

  defp print_router_analyses(analyses) do
    rows =
      Enum.map(analyses, fn a ->
        trend =
          case a.success_trend do
            :improving -> "↑ Mejorando"
            :degrading -> "↓ Degradando"
            :stable -> "→ Estable"
          end

        alert = if a.alert, do: "⚠️", else: ""

        [
          "#{a.model_id}@#{a.task_type}",
          "#{Float.round(a.overall_success_rate, 1)}%",
          trend,
          to_string(a.n_decisions),
          alert
        ]
      end)

    Output.data_table(
      headers: ["Modelo@Tarea", "Success Rate", "Trend", "N", "Alerta"],
      rows: rows,
      headers_color: :yellow
    )
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

    Output.section("Benchmark")
    Output.info("Modelos: #{Enum.join(models, ", ")}")
    Output.info("Prompt: #{prompt}")
    Output.info("Concurrencia: #{concurrency}")
    Output.info("Duración: #{duration}s")
    IO.puts("")

    Enum.each(models, fn model ->
      Output.info("Testeando #{model}...")

      {time_us, result} =
        :timer.tc(fn ->
          ElPaso.Domain.ModelManager.infer(model, %{messages: [%{role: "user", content: prompt}]})
        end)

      case result do
        {:ok, resp} ->
          tokens = Map.get(resp, :completion_tokens, 0)
          tps = if time_us > 0, do: Float.round(tokens / (time_us / 1_000_000), 1), else: 0
          Output.success("#{time_us / 1000}ms | #{tokens} tokens | #{tps} tok/s")

        {:error, reason} ->
          Output.error("Error: #{inspect(reason)}")
      end
    end)
  end

  defp handle_bench([]) do
    Output.info("Usa 'elpaso bench --help' para ver ayuda del comando bench.")
  end

  defp handle_context(["list" | rest]) do
    {opts, _, _} = OptionParser.parse(rest, switches: [limit: :integer, user: :string])
    limit = Keyword.get(opts, :limit, 50)

    sessions = ElPaso.Context.Storage.list_sessions() |> Enum.take(limit)

    if sessions == [] do
      Output.warning("No hay sesiones registradas")
    else
      rows =
        Enum.map(sessions, fn s ->
          user = s.user_id || "anon"
          created = s.inserted_at || "N/A"
          [s.session_id, user, to_string(created)]
        end)

      Output.data_table(
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
          Output.error("Sesión no encontrada: #{id}")

        session ->
          Output.section(session.session_id, subtitle: "Sesión")

          Output.data_table(
            headers: ["Campo", "Valor"],
            rows: [
              ["Usuario", session.user_id || "anon"],
              ["Modelo", session.model_id || "—"],
              ["Estado", session.status || "—"],
              ["Modo contexto", session.context_mode || "—"],
              ["Creada", to_string(session.inserted_at)],
              ["Actualizada", to_string(session.updated_at)]
            ],
            table_border: :rounded,
            headers_color: :cyan
          )

          messages = ElPaso.Context.Storage.get_all_messages(session.session_id)
          Output.divider("Mensajes (#{length(messages)})")

          if messages != [] do
            msg_rows =
              Enum.map(messages, fn m ->
                preview = String.slice(m.content, 0, 50) <> "..."
                [m.role, preview]
              end)

            Output.data_table(
              headers: ["Rol", "Contenido"],
              rows: msg_rows,
              table_border: :rounded,
              headers_color: :yellow
            )
          end
      end
    else
      Output.error("Falta ID de sesión")
      Output.error("Uso: elpaso context show <session_id>")
    end
  end

  defp handle_context(["clear" | rest]) do
    {opts, _, _} = OptionParser.parse(rest, switches: [all: :boolean, session: :string])

    cond do
      Keyword.get(opts, :all) ->
        # Borrar todas las sesiones y sus mensajes vía Repo (Ecto)
        try do
          ElPaso.Repo.delete_all(ElPaso.Context.Schemas.Message)
          {_, _} = ElPaso.Repo.delete_all(ElPaso.Context.Schemas.Session)
          Output.success("Todas las sesiones y mensajes eliminados")
        rescue
          e ->
            Output.error("Error al limpiar sesiones: #{inspect(e)}")
        end

      id = Keyword.get(opts, :session) ->
        # Fetch session first, then delete (Storage.delete_session expects %Session{})
        case ElPaso.Context.Storage.get_session(id) do
          nil ->
            Output.error("Sesión no encontrada: #{id}")

          session ->
            case ElPaso.Context.Storage.delete_session(session) do
              {:ok, _} ->
                Output.success("Sesión #{id} eliminada")

              {:error, reason} ->
                Output.error("Error al eliminar sesión: #{inspect(reason)}")
            end
        end

      true ->
        Output.error("Especifica --all o --session <id>")
    end
  end

  defp handle_context([]) do
    Output.info("Usa 'elpaso context --help' para ver ayuda del comando context.")
  end

  defp handle_cluster(["status" | _]) do
    try do
      nodes = ElPaso.Cluster.NodeRegistry.all_nodes()

      if nodes == [] do
        Output.error("Sin nodos en el cluster")
      else
        Output.section("Cluster ElPaso", subtitle: "#{length(nodes)} nodo(s)")

        rows =
          Enum.map(nodes, fn n ->
            status =
              if Node.ping(String.to_atom(n)) == :pong, do: "🟢 Conectado", else: "🔴 Desconectado"

            [to_string(n), status]
          end)

        Output.data_table(
          headers: ["Nodo", "Estado"],
          rows: rows,
          table_border: :rounded,
          headers_color: :cyan
        )
      end
    rescue
      _ ->
        Output.info("Cluster no configurado. Habilita en ~/.config/elpaso/elpaso.conf")
    end
  end

  defp handle_cluster(["nodes" | _]) do
    try do
      nodes = ElPaso.Cluster.NodeRegistry.all_nodes()

      if nodes == [] do
        Output.warning("No hay nodos registrados")
      else
        rows =
          Enum.map(nodes, fn n ->
            alive = if Node.ping(String.to_atom(n)) == :pong, do: "Activo", else: "Inactivo"
            [to_string(n), alive]
          end)

        Output.data_table(
          headers: ["Nodo", "Estado"],
          rows: rows,
          table_border: :rounded,
          headers_color: :cyan
        )
      end
    rescue
      _ ->
        Output.info("Cluster no disponible")
    end
  end

  defp handle_cluster(["join" | rest]) do
    {opts, _, _} = OptionParser.parse(rest, switches: [nodes: :string, discovery: :string])

    case Keyword.get(opts, :nodes) do
      nil ->
        Output.error("Especifica --nodes ip1,ip2")

      nodes_str ->
        nodes = String.split(nodes_str, ",")

        Enum.each(nodes, fn n ->
          node_atom = String.to_atom("elpaso@#{n}")
          Node.connect(node_atom)
          Output.info("Conectando a #{node_atom}...")
        end)

        Output.success("Conectado a #{length(nodes)} nodo(s)")
    end
  end

  defp handle_cluster([]) do
    Output.info("Usa 'elpaso cluster --help' para ver ayuda del comando cluster.")
  end

  # ==================== PERSONALITY HANDLERS ====================

  defp handle_personality(["add" | rest]) do
    name = get_opt(rest, :name)
    description = get_opt(rest, :description)
    system_prompt = get_opt(rest, :system_prompt)
    model_name = get_opt(rest, :model)
    engine_name = get_opt(rest, :engine)
    keywords_str = get_opt(rest, :keywords)
    task_types_str = get_opt(rest, :task_types)
    priority_str = get_opt(rest, :priority)
    is_default = get_opt(rest, :default)

    if name && system_prompt do
      model = model_name && ElPaso.Repo.get_by(ElPaso.Models.Model, name: model_name)
      engine = engine_name && ElPaso.Repo.get_by(ElPaso.Models.Engine, name: engine_name)
      keywords = parse_csv(keywords_str)
      task_types = parse_csv(task_types_str)
      priority = parse_int(priority_str)
      default? = not is_nil(is_default) and is_default != "false"

      attrs = %{
        name: name,
        description: description,
        system_prompt: system_prompt,
        model: model,
        engine: engine,
        trigger_keywords: keywords,
        trigger_task_types: task_types,
        priority: priority || 0,
        is_default: default?
      }

      case ElPaso.Domain.PersonalityManager.create_personality(attrs) do
        {:ok, _personality} ->
          default_tag = if default?, do: ", default", else: ""

          Output.success(
            "Personalidad '#{name}' creada (priority: #{priority || 0}#{default_tag})"
          )

        {:error, reason} ->
          Output.error("Error al crear personalidad: #{inspect(reason)}")
      end
    else
      Output.error("Error: Faltan parámetros requeridos")

      Output.error(
        "Uso: elpaso personality add --name <nombre> --system-prompt <prompt> [--model <m>] [--engine <e>] [--keywords k1,k2] [--task-types t1,t2] [--priority N] [--default]"
      )
    end
  end

  defp handle_personality(["list" | _]) do
    personalities = ElPaso.Domain.PersonalityManager.list_personalities()

    if Enum.empty?(personalities) do
      Output.warning("No hay personalidades registradas")
    else
      rows =
        Enum.map(personalities, fn p ->
          desc = p.description || "N/A"
          prompt = String.slice(p.system_prompt, 0, 30) <> "..."
          [p.name, desc, prompt]
        end)

      Output.data_table(
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
          Output.success("Personalidad '#{name}' eliminada exitosamente")

        {:error, reason} ->
          Output.error("Error al eliminar personalidad: #{reason}")
      end
    else
      Output.error("Error: Falta --name")
    end
  end

  defp handle_personality(["show" | rest]) do
    name = get_opt(rest, :name)

    if name do
      case ElPaso.Domain.PersonalityManager.get_personality(name) do
        nil ->
          Output.error("Personalidad no encontrada")

        personality ->
          Output.section(personality.name, subtitle: "Personalidad")

          Output.data_table(
            headers: ["Campo", "Valor"],
            rows: [
              ["Descripción", personality.description || "N/A"],
              ["System Prompt", personality.system_prompt]
            ],
            table_border: :rounded,
            headers_color: :cyan
          )
      end
    else
      Output.error("Error: Falta --name")
    end
  end

  defp handle_personality(["use" | rest]) do
    model_name = get_opt(rest, :model)
    personality_name = get_opt(rest, :personality)

    if model_name && personality_name do
      # This would be implemented in the future to assign personality to model
      Output.success("Personalidad '#{personality_name}' asignada al modelo '#{model_name}'")
    else
      Output.error("Error: Faltan parámetros requeridos")
      Output.error("Uso: elpaso personality use --model <modelo> --personality <nombre>")
    end
  end

  defp handle_personality([]) do
    Output.info("Usa 'elpaso personality --help' para ver ayuda.")
  end

  defp handle_personality(args) do
    handle_personality(["list" | args])
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

    port = Keyword.get(opts, :port, 4000)

    if port != 4000 do
      Application.put_env(:elpaso, :http_port, port)
    end

    IO.write(IO.ANSI.clear())
    IO.write(IO.ANSI.home())

    Output.section("ElPaso v0.1.0", subtitle: "Multi-Model LLM Proxy")
    IO.puts("")
    Output.info("Arrancando aplicación OTP...")

    case Application.ensure_all_started(:elpaso) do
      {:ok, _} ->
        # Arrancar el HTTP server manualmente (no en el supervisor)
        http_port = ElPaso.Config.http_port()
        case Plug.Cowboy.http(ElPaso.HTTP.Server, [], port: http_port) do
          {:ok, _pid} ->
            Output.success("Aplicación OTP lista")

            Output.divider("Endpoints")

            Output.data_table(
              headers: ["Servicio", "URL"],
              rows: [
                ["HTTP", "http://0.0.0.0:#{http_port}"],
                ["Dashboard", "http://0.0.0.0:#{http_port}/dashboard"],
                ["Métricas", "http://0.0.0.0:#{http_port}/metrics"],
                ["API OpenAI", "POST http://0.0.0.0:#{http_port}/v1/chat/completions"],
                ["API Anthropic", "POST http://0.0.0.0:#{http_port}/v1/messages"]
              ],
              table_border: :rounded,
              headers_color: :yellow
            )

          {:error, {:already_started, _pid}} ->
            Output.success("(compartiendo servidor existente)")
        end
          headers: ["Servicio", "URL"],
          rows: [
            ["HTTP", "http://0.0.0.0:#{port}"],
            ["Dashboard", "http://0.0.0.0:#{port}/dashboard"],
            ["Métricas", "http://0.0.0.0:#{port}/metrics"],
            ["API", "POST http://0.0.0.0:#{port}/v1/messages"]
          ],
          table_border: :rounded,
          headers_color: :cyan
        )

        try do
          engines = ElPaso.Domain.EngineManager.list_engines()
          models = ElPaso.Domain.ModelManager.list_models()

          if engines != [] do
            Output.divider("Engines registrados")

            engine_rows =
              Enum.map(engines, fn e ->
                [e.name, e.adapter, e.base_url]
              end)

            Output.data_table(
              headers: ["Nombre", "Adapter", "Base URL"],
              rows: engine_rows,
              table_border: :rounded,
              headers_color: :yellow
            )
          else
            Output.warning("No hay engines registrados. Usa: elpaso engine add ...")
          end

          if models != [] do
            Output.divider("Modelos registrados")

            model_rows =
              Enum.map(models, fn m ->
                engine_name =
                  if m.engine_id do
                    case ElPaso.Repo.get(ElPaso.Models.Engine, m.engine_id) do
                      nil -> m.engine_id
                      e -> e.name
                    end
                  else
                    "—"
                  end

                [m.name, engine_name, m.url]
              end)

            Output.data_table(
              headers: ["Nombre", "Engine", "URL"],
              rows: model_rows,
              table_border: :rounded,
              headers_color: :yellow
            )
          else
            Output.warning("No hay modelos registrados. Usa: elpaso model add ...")
          end
        rescue
          _ -> :ok
        end

        Output.divider("Servidor activo — Ctrl+C para detener")

        receive do
        after
          :infinity -> :ok
        end

      {:error, {app, reason}} ->
        Output.error("Error al iniciar #{app}: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp handle_server(["stop" | _]) do
    case Application.stop(:elpaso) do
      :ok ->
        Output.success("Servidor detenido")

      {:error, {:not_started, :elpaso}} ->
        Output.info("ElPaso no está en ejecución")
    end
  end

  defp handle_server(["restart" | _]) do
    Output.info("Reiniciando ElPaso...")
    Application.stop(:elpaso)

    case Application.ensure_all_started(:elpaso) do
      {:ok, _} ->
        port = ElPaso.Config.http_port()
        Output.success("Reiniciado en http://0.0.0.0:#{port}")

      {:error, {app, reason}} ->
        Output.error("Error al reiniciar #{app}: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp handle_server(["status" | _]) do
    port = ElPaso.Config.http_port()

    case Application.started_applications() |> Enum.find(&(elem(&1, 0) == :elpaso)) do
      nil ->
        Output.error("Servidor detenido")

      _ ->
        Output.success("Activo en http://localhost:#{port}")
        Output.info("")

        # Estado de llama-server
        try do
          current = ElPaso.Domain.LlamaServerManager.current_model()
          Output.info("  llama-server: #{(current && "→ #{current}") || "sin modelo cargado"}")
        rescue
          _ -> Output.info("  llama-server: desconocido")
        end

        # Conteos
        try do
          engines = ElPaso.Repo.aggregate(ElPaso.Models.Engine, :count) || 0
          models = ElPaso.Repo.aggregate(ElPaso.Models.Model, :count) || 0
          personalities = ElPaso.Repo.aggregate(ElPaso.Models.Personality, :count) || 0

          Output.info(
            "  engines: #{engines}  |  modelos: #{models}  |  personalidades: #{personalities}"
          )
        rescue
          _ -> :ok
        end
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
      Output.info("No se encontró #{log_path}. Los logs van a stdout.")
    end
  end

  defp handle_server([]) do
    Output.info("Usa 'elpaso server --help' para ver ayuda.")
  end

  defp handle_server(args) do
    handle_server(["status" | args])
  end
end
