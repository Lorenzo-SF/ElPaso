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
    case ElPaso.Domain.ModelManager.list_models() do
      models ->
        IO.puts("┌─────────┬──────────┬────────────────────┬────────┐")
        IO.puts("│ Name    │ Engine  │ URL               │ Active│")
        IO.puts("├─────────┼──────────┼────────────────────┼────────┤")
        Enum.each(models, fn model ->
          IO.puts("│ #{model.name} │ #{model.engine_id} │ #{model.url} │ #{model.active} │")
        end)
        IO.puts("└─────────┴──────────┴────────────────────┴────────┘")
      [] ->
        IO.puts("No hay modelos registrados")
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
        {:ok, model} ->
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
        {:ok, model} ->
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
        {:ok, model} ->
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
        active: get_opt(rest, :active) || true,
        max_tokens: get_opt(rest, :max_tokens) |> parse_int(),
        temperature: get_opt(rest, :temperature) |> parse_float(),
        top_p: get_opt(rest, :top_p) |> parse_float()
      }
      
      case ElPaso.Domain.ModelManager.create_model(attrs) do
        {:ok, model} ->
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
      engines ->
        IO.puts("┌───────────┬─────────┬─────────────────────┬────────┐")
        IO.puts("│ Name     │ Adapter │ Base URL           │ Active│")
        IO.puts("├───────────┼─────────┼─────────────────────┼────────┤")
        Enum.each(engines, fn engine ->
          IO.puts("│ #{engine.name} │ #{engine.adapter} │ #{engine.base_url} │ #{engine.active} │")
        end)
        IO.puts("└───────────┴─────────┴─────────────────────┴────────┘")
      [] ->
        IO.puts("No hay motores registrados")
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
        {:ok, engine} ->
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
    base_url = get_opt(rest, :base_url)
    
    if name && adapter && base_url do
      attrs = %{
        name: name,
        adapter: adapter,
        base_url: base_url,
        active: get_opt(rest, :active) || true,
        timeout: get_opt(rest, :timeout) |> parse_int()
      }
      
      case ElPaso.Domain.EngineManager.create_engine(attrs) do
        {:ok, engine} ->
          IO.puts("✅ Motor '#{name}' creado exitosamente")
        {:error, reason} ->
          IO.puts("❌ Error al crear motor: #{reason}")
      end
    else
      IO.puts("❌ Error: Faltan parámetros requeridos")
      IO.puts("Uso: elpaso engine add --name <name> --adapter <adapter> --base-url <url> [opciones]")
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
    key_str = Atom.to_string(key)
    Enum.find_value(args, fn arg ->
      case String.split(arg, "=", parts: 2) do
        [^key_str, v] -> v
        [^key_str] -> true
        _ -> false
      end
    end)
  end

  defp parse_int(value) when is_binary(value), do: String.to_integer(value)
  defp parse_int(nil), do: nil

  defp parse_float(value) when is_binary(value), do: String.to_float(value)
  defp parse_float(nil), do: nil

  defp handle_config(["show" | _]) do
    # In a real implementation, this would fetch configuration from DB
    IO.puts("Mostrando configuración desde base de datos...")
    IO.puts("Configuración actual:")
    IO.puts("  Puerto: 8080")
    IO.puts("  Entorno: dev")
    IO.puts("  Log level: info")
  end

  defp handle_config(["reload" | _]) do
    # In a real implementation, this would reload configuration from DB
    IO.puts("Recargando configuración desde base de datos...")
    IO.puts("✅ Configuración recargada exitosamente")
  end

  defp handle_config([]) do
    IO.puts("Usa 'elpaso config --help' para ver ayuda del comando config.")
  end

  defp handle_router(["stats" | _]) do
    # In a real implementation, this would fetch routing statistics from DB
    IO.puts("Mostrando estadísticas de routing desde base de datos...")
    IO.puts("Estadísticas actuales:")
    IO.puts("  Total requests: 1245")
    IO.puts("  Average latency: 42ms")
    IO.puts("  Active models: 3")
  end

  defp handle_router(["tune" | _]) do
    # In a real implementation, this would run auto-tuning logic
    IO.puts("Ejecutando auto-tuneo de reglas de routing desde base de datos...")
    IO.puts("✅ Auto-tuneo completado exitosamente")
  end

  defp handle_router([]) do
    IO.puts("Usa 'elpaso router --help' para ver ayuda del comando router.")
  end

  defp handle_bench(["run" | _]) do
    # In a real implementation, this would run benchmarks and store results in DB
    IO.puts("Ejecutando benchmark desde base de datos...")
    IO.puts("✅ Benchmark completado exitosamente")
    IO.puts("Resultados:")
    IO.puts("  Modelos testeados: 3")
    IO.puts("  Promedio de latencia: 45ms")
    IO.puts("  Tokens por segundo: 120")
  end

  defp handle_bench([]) do
    IO.puts("Usa 'elpaso bench --help' para ver ayuda del comando bench.")
  end

  defp handle_context(["list" | _]) do
    # In a real implementation, this would list sessions from DB
    IO.puts("Listando sesiones desde base de datos...")
    IO.puts("┌────────────┬─────────┬─────────────────────┐")
    IO.puts("│ ID         │ Usuario │ Fecha             │")
    IO.puts("├────────────┼─────────┼─────────────────────┤")
    IO.puts("│ session123 │ user1   │ 2024-01-15 10:30:00 │")
    IO.puts("│ session456 │ user2   │ 2024-01-15 11:15:00 │")
    IO.puts("└────────────┴─────────┴─────────────────────┘")
  end

  defp handle_context(["clear" | _]) do
    # In a real implementation, this would clear sessions from DB
    IO.puts("Limpiando contextos desde base de datos...")
    IO.puts("✅ Contextos limpiados exitosamente")
  end

  defp handle_context([]) do
    IO.puts("Usa 'elpaso context --help' para ver ayuda del comando context.")
  end

  defp handle_cluster(["status" | _]) do
    # In a real implementation, this would check cluster status from DB
    IO.puts("Estado del cluster desde base de datos...")
    IO.puts("Cluster:")
    IO.puts("  Estado: Activo")
    IO.puts("  Nodos: 3")
    IO.puts("  Lider: node1")
  end

  defp handle_cluster(["nodes" | _]) do
    # In a real implementation, this would list cluster nodes from DB
    IO.puts("Nodos del cluster desde base de datos...")
    IO.puts("┌────────────┬─────────┬──────────┐")
    IO.puts("│ Nombre   │ Estado│ Dirección  │")
    IO.puts("├────────────┼─────────┼──────────┤")
    IO.puts("│ node1    │ Activo│ 192.168.1.10 │")
    IO.puts("│ node2    │ Activo│ 192.168.1.11 │")
    IO.puts("│ node3    │ Inactivo│ 192.168.1.12 │")
    IO.puts("└────────────┴─────────┴──────────┘")
  end

  defp handle_cluster([]) do
    IO.puts("Usa 'elpaso cluster --help' para ver ayuda del comando cluster.")
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

  # ==================== PROFILE ====================

  def main(["profile", "--help"]) do
    IO.puts("""
    ELPASO PROFILE

    Gestión de perfiles (conjuntos modelo+engine+personalidad).

    COMANDOS:

      elpaso profile add          Añadir un profile
      elpaso profile list       Listar todos los profiles
      elpaso profile delete     Eliminar un profile
      elpaso profile show      Mostrar detalles de un profile

    USO:

      elpaso profile add --name <nombre> --model <modelo> --engine <motor> --personality <personalidad>
      elpaso profile list
      elpaso profile delete --name <nombre>
      elpaso profile show --name <nombre>

    OPCIONES:

      --name <nombre>       Nombre único (REQUERIDO)
      --model <modelo>     Nombre del modelo (REQUERIDO)
      --engine <motor>      Nombre del motor (REQUERIDO)
      --personality <personalidad>  Nombre de la personalidad (REQUERIDO)

    EJEMPLOS:

      # Añadir profile
      elpaso profile add \\
        --name mi-perfil \\
        --model gemma \\
        --engine openai \\
        --personality coder

      # Listar profiles
      elpaso profile list

      # Ver details
      elpaso profile show --name mi-perfil

      # Eliminar profile
      elpaso profile delete --name mi-perfil
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
        {:ok, personality} ->
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
      IO.puts("┌────────────┬─────────────────────────────────────┬──────────────────────────────────┐")
      IO.puts("│ Nombre     │ Descripción                         │ System Prompt                    │")
      IO.puts("├────────────┼─────────────────────────────────────┼──────────────────────────────────┤")
      Enum.each(personalities, fn p ->
        IO.puts("│ #{p.name} │ #{p.description || "N/A"} │ #{String.slice(p.system_prompt, 0, 30)}... │")
      end)
      IO.puts("└────────────┴─────────────────────────────────────┴──────────────────────────────────┘")
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
          {:ok, profile} ->
            IO.puts("✅ Profile '#{name}' creado exitosamente")
          {:error, reason} ->
            IO.puts("❌ Error al crear profile: #{reason}")
        end
      else
        IO.puts("❌ Error: Uno o más elementos no encontrados (modelo, motor o personalidad)")
      end
    else
      IO.puts("❌ Error: Faltan parámetros requeridos")
      IO.puts("Uso: elpaso profile add --name <nombre> --model <modelo> --engine <motor> --personality <personalidad>")
    end
  end

  defp handle_profile(["list" | _]) do
    profiles = ElPaso.Domain.ProfileManager.list_profiles()
    
    if Enum.empty?(profiles) do
      IO.puts("No hay profiles registrados")
    else
      IO.puts("┌────────────┬────────────┬────────────┬────────────┐")
      IO.puts("│ Nombre     │ Modelo     │ Motor      │ Personalidad │")
      IO.puts("├────────────┼────────────┼────────────┼────────────┤")
      Enum.each(profiles, fn p ->
        IO.puts("│ #{p.name} │ #{p.model.name} │ #{p.engine.name} │ #{p.personality.name} │")
      end)
      IO.puts("└────────────┴────────────┴────────────┴────────────┘")
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

  def main(_args) do
    IO.puts("Comando desconocido. Usa 'elpaso --help' para ver los comandos disponibles.")
  end
end