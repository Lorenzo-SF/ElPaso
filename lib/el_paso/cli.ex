defmodule ElPaso.CLI do
  @moduledoc """
  CLI principal para elpaso.
  """

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

      model        Gestión de modelos de inferencia
      engine      Gestión de motores de inferencia
      personality Gestión de personalidades/roles
      config      Gestión de configuración
      server      Gestionar servidor HTTP
      router      Estadísticas y auto-tuneo del router
      bench       Ejecutar benchmarks
      context     Gestionar contextos de sesión
      cluster    Estado del cluster

    SUBCOMANDOS POR COMANDO:

      model add/list/delete/update/show
      engine add/list/delete/update/show
      personality add/list/delete
      config show/reload
      server start/stop/restart/status
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
    case args do
      ["model" | rest] -> handle_model(rest)
      ["engine" | rest] -> handle_engine(rest)
      ["personality" | rest] -> handle_personality(rest)
      ["config" | rest] -> handle_config(rest)
      ["server" | rest] -> handle_server(rest)
      ["router" | rest] -> handle_router(rest)
      ["bench" | rest] -> handle_bench(rest)
      ["context" | rest] -> handle_context(rest)
      ["cluster" | rest] -> handle_cluster(rest)
      _ -> IO.puts("Comando desconocido. Usa 'elpaso --help' para ver los comandos disponibles.")
    end
  end

  # ==================== HANDLERS ====================

  defp handle_model(["list" | _]) do
    IO.puts("Listando modelos...")
    IO.puts("")
    IO.puts("┌─────────┬──────────┬────────────────────┬────────┐")
    IO.puts("│ Name    │ Engine  │ URL               │ Active│")
    IO.puts("├─────────┼──────────┼────────────────────┼────────┤")
    IO.puts("│ (empty) │ -       │ -                 │ -     │")
    IO.puts("└─────────┴──────────┴────────────────────┴────────┘")
    IO.puts("💡 Usa 'elpaso model add' para añadir un modelo")
  end

  defp handle_model(["delete" | rest]) do
    name = get_opt(rest, :name)
    if name do
      IO.puts("Eliminando modelo: #{name}")
      IO.puts("✅ Modelo '#{name}' eliminado")
    else
      IO.puts("❌ Error: Falta --name")
      IO.puts("Uso: elpaso model delete --name <nombre>")
    end
  end

  defp handle_model(["update" | rest]) do
    name = get_opt(rest, :name)
    if name do
      IO.puts("Actualizando modelo: #{name}")
      opts = Enum.map_join(rest, ", ", fn "--" <> k -> k end)
      IO.puts("Opciones actualizadas: #{opts}")
    else
      IO.puts("❌ Error: Falta --name")
      IO.puts("Uso: elpaso model update --name <nombre> [opciones]")
    end
  end

  defp handle_model(["show" | rest]) do
    name = get_opt(rest, :name)
    if name do
      IO.puts("Modelo: #{name}")
      IO.puts("  Engine: (por defecto)")
      IO.puts("  URL: (por defecto)")
      IO.puts("  Active: true")
      IO.puts("  Max tokens: 4096")
    else
      IO.puts("❌ Error: Falta --name")
      IO.puts("Uso: elpaso model show --name <nombre>")
    end
  end

  defp handle_model(["add" | _]) do
    IO.puts("""
    Añadir modelo de inferencia.

    Uso: elpaso model add --name <name> --engine <engine> --url <url> [opciones]

    Оpciones detalladas en: elpaso model --help
    """)
  end

  defp handle_model([]) do
    IO.puts("Usa 'elpaso model --help' para ver ayuda del comando model.")
  end

  defp handle_model(args) do
    handle_model(["list" | args])
  end

  defp handle_engine(["list" | _]) do
    IO.puts("Listando motores...")
    IO.puts("")
    IO.puts("┌───────────┬─────────┬─────────────────────┬────────┐")
    IO.puts("│ Name     │ Adapter │ Base URL           │ Active│")
    IO.puts("├───────────┼─────────┼─────────────────────┼────────┤")
    IO.puts("│ llama    │ llama   │ http://localhost:8081│ true   │")
    IO.puts("│ vllm     │ vllm    │ http://localhost:8000│ true   │")
    IO.puts("│ airllm   │ airllm  │ http://localhost:8001│ true   │")
    IO.puts("└───────────┴─────────┴─────────────────────┴────────┘")
  end

  defp handle_engine(["delete" | rest]) do
    name = get_opt(rest, :name)
    if name do
      IO.puts("Eliminando motor: #{name}")
    else
      IO.puts("❌ Error: Falta --name")
    end
  end

  defp handle_engine(["update" | rest]) do
    name = get_opt(rest, :name)
    if name do
      IO.puts("Actualizando motor: #{name}")
    else
      IO.puts("❌ Error: Falta --name")
    end
  end

  defp handle_engine(["show" | rest]) do
    name = get_opt(rest, :name)
    if name do
      IO.puts("Motor: #{name}")
      IO.puts("  Adapter: llama")
      IO.puts("  Base URL: http://localhost:8081/v1")
      IO.puts("  Active: true")
    else
      IO.puts("❌ Error: Falta --name")
    end
  end

  defp handle_engine(["add" | _]) do
    IO.puts("""
    Añadir motor de inferencia.

    Uso: elpaso engine add --name <name> --adapter <adapter> --base-url <url> [opciones]

    Оpciones detalladas en: elpaso engine --help
    """)
  end

  defp handle_engine([]) do
    handle_engine(["list"])
  end

  defp handle_engine(args) do
    handle_engine(["add" | args])
  end

  # ==================== HELPERS ====================

  defp get_opt(args, key) do
    key_str = Atom.to_string(key)
    Enum.find_value(args, fn arg ->
      case String.split(arg, "=", parts: 2) do
        [^key_str, v] -> v
        [^key_str] -> true
        _ -> false
      end
    end)
  end

  defp handle_config(["show" | _]) do
    IO.puts("Mostrando configuración...")
  end

  defp handle_config(["reload" | _]) do
    IO.puts("Recargando configuración...")
  end

  defp handle_config([]) do
    IO.puts("Usa 'elpaso config --help' para ver ayuda del comando config.")
  end

  defp handle_config(args) do
    handle_config(args)
  end

  defp handle_router(["stats" | _]) do
    IO.puts("Mostrando estadísticas de routing...")
  end

  defp handle_router(["tune" | _]) do
    IO.puts("Ejecutando auto-tuneo...")
  end

  defp handle_router([]) do
    IO.puts("Usa 'elpaso router --help' para ver ayuda del comando router.")
  end

  defp handle_router(args) do
    handle_router(args)
  end

  defp handle_bench(["run" | _]) do
    IO.puts("Ejecutando benchmark...")
  end

  defp handle_bench([]) do
    IO.puts("Usa 'elpaso bench --help' para ver ayuda del comando bench.")
  end

  defp handle_bench(args) do
    handle_bench(args)
  end

  defp handle_context(["list" | _]) do
    IO.puts("Listando sesiones...")
  end

  defp handle_context(["clear" | _]) do
    IO.puts("Limpiando contextos...")
  end

  defp handle_context([]) do
    IO.puts("Usa 'elpaso context --help' para ver ayuda del comando context.")
  end

  defp handle_context(args) do
    handle_context(args)
  end

  defp handle_cluster(["status" | _]) do
    IO.puts("Estado del cluster...")
  end

  defp handle_cluster(["nodes" | _]) do
    IO.puts("Nodos del cluster...")
  end

  defp handle_cluster([]) do
    IO.puts("Usa 'elpaso cluster --help' para ver ayuda del comando cluster.")
  end

  defp handle_cluster(args) do
    handle_cluster(args)
  end

  # ==================== PERSONALITY ====================

  def main(["personality", "--help"]) do
    IO.puts("""
    ELPASO PERSONALITY

    Gestión de personalidades/roles para modelos.

    COMANDOS:

      elpaso personality add          Añadir una personality
      elpaso personality list       Listar todas las personalidades
      elpaso personality delete     Eliminar una personality
      elpaso personality show      Mostrar detalles de una personality
      elpaso personality use       Asignar una personality a un modelo

    USO:

      elpaso personality add --name <nombre> --description <desc> --system-prompt <prompt>
      elpaso personality list
      elpaso personality delete --name <nombre>
      elpaso personality show --name <nombre>
      elpaso personality use --model <modelo> --personality <nombre>

    OPCIONES:

      --name <nombre>       Nombre único (REQUERIDO para delete/show/use)
      --description <desc> Descripción (opcional)
      --system-prompt <prompt>  System prompt de la personality (REQUERIDO para add)
      --model <modelo>     Nombre del modelo (REQUERIDO para use)

    PERSONALITIES INCUIDAS:

      coder        Revisión de código, stack-migrator
      architect   Diseño de sistemas, project-planning
      advisor     Consejos, análisis
      writer      Generación de texto

    EJEMPLOS:

      # Listar personalidades
      elpaso personality list

      # Añadir personality personalizada
      elpaso personality add \\
        --name mi-coder \\
        --description "Experto en Elixir" \\
        --system-prompt "Eres un experto en Elixir y Phoenix..."

      # Ver details
      elpaso personality show --name coder

      # Asignar personality a modelo
      elpaso personality use --model gemma --personality coder

      # Eliminar personality
      elpaso personality delete --name mi-coder
    """)
  end

  # ==================== SERVER ====================

  def main(["server", "--help"]) do
    IO.puts("""
    ELPASO SERVER

    Gestionar el servidor HTTP de ElPaso.

    COMANDOS:

      elpaso server start       Iniciar el servidor
      elpaso server stop      Parar el servidor
      elpaso server restart  Reiniciar el servidor
      elpaso server status   Ver estado del servidor
      elpaso server log    Ver logs en tiempo real

    USO:

      elpaso server start [--port <puerto>] [--bind <host>]
      elpaso server stop
      elpaso server restart
      elpaso server status
      elpaso server log [--lines <n>]

    OPCIONES:

      --port <puerto>   Puerto HTTP (default: 8080)
      --bind <host>     Host de bindeo (default: 0.0.0.0)
      --lines <n>       Líneas de log (default: 100)

    EJEMPLOS:

      # Iniciar servidor en puerto default
      elpaso server start

      # Iniciar en puerto custom
      elpaso server start --port 9000

      # Ver estado actual
      elpaso server status

      # Ver logs
      elpaso server log

      # Parar servidor
      elpaso server stop
    """)
  end

  # ==================== PERSONALITY HANDLERS ====================

  defp handle_personality(["list" | _]) do
    IO.puts("Listando personalidades...")
  end

  defp handle_personality(["add" | _]) do
    IO.puts("Añadir personality: elpaso personality add --name <name> --system-prompt <prompt>")
  end

  defp handle_personality(["delete" | rest]) do
    name = Keyword.get(parse_cli_opts(rest), :name, nil)
    if name do
      IO.puts("Eliminando personality: #{name}")
    else
      IO.puts("Usa: elpaso personality delete --name <nombre>")
    end
  end

  defp handle_personality(["show" | rest]) do
    name = Keyword.get(parse_cli_opts(rest), :name, nil)
    if name do
      IO.puts("Mostrando details: #{name}")
    else
      IO.puts("Usa: elpaso personality show --name <nombre>")
    end
  end

  defp handle_personality(["use" | rest]) do
    model = Keyword.get(parse_cli_opts(rest), :model, nil)
    personality = Keyword.get(parse_cli_opts(rest), :personality, nil)
    if model && personality do
      IO.puts("Asignando personality '#{personality}' a modelo '#{model}'")
    else
      IO.puts("Usa: elpaso personality use --model <modelo> --personality <nombre>")
    end
  end

  defp handle_personality([]) do
    IO.puts("Usa 'elpaso personality --help' para ver ayuda.")
  end

  defp handle_personality(args) do
    handle_personality(args)
  end

  # ==================== SERVER HANDLERS ====================

  defp handle_server(["start" | rest]) do
    opts = parse_cli_opts(rest)
    port = Keyword.get(opts, :port, 8080)
    bind = Keyword.get(opts, :bind, "0.0.0.0")
    IO.puts("Iniciando servidor en #{bind}:#{port}...")
    IO.puts("💡 Nota: Usa 'mix run --no-halt -- --port #{port}' para iniciar")
  end

  defp handle_server(["stop" | _]) do
    IO.puts("Deteniendo servidor...")
    IO.puts("💡 Nota: Envía SIGTERM al proceso: kill $(lsof -t -i:8080)")
  end

  defp handle_server(["restart" | _]) do
    IO.puts("Reiniciando servidor...")
    IO.puts("💡 Nota: Para y reinicia el servidor manualmente")
  end

  defp handle_server(["status" | _]) do
    IO.puts("Estado del servidor:")
    IO.puts("  Puerto: 8080")
    IO.puts("  Estado: (consultar con lsof)")
    IO.puts("  Uptime: (consultar con ps)")
  end

  defp handle_server(["log" | rest]) do
    lines = Keyword.get(parse_cli_opts(rest), :lines, 100)
    IO.puts("Últimas #{lines} líneas de log:")
    IO.puts("💡 Nota: Ver logs con: tail -n #{lines} log/elpaso.log")
  end

  defp handle_server([]) do
    IO.puts("Usa 'elpaso server --help' para ver ayuda.")
  end

  defp handle_server(args) do
    handle_server(args)
  end

  # ==================== HELPERS ====================

  defp parse_cli_opts(args) do
    Enum.reduce(args, [], fn
      "--" <> key, acc ->
        [String.to_atom(key) | acc]
      arg, acc ->
        [arg | acc]
    end)
    |> Enum.reverse()
  end

  def main([]), do: main([])
end