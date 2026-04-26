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
      config      Gestión de configuración
      router      Estadísticas y auto-tuneo del router
      bench       Ejecutar benchmarks
      context     Gestionar contextos de sesión
      cluster    Estado del cluster

    VER AYUDA ESPECÍFICA:
      elpaso model --help
      elpaso engine --help
      elpaso config --help
      elpaso router --help
      elpaso bench --help
      elpaso context --help
      elpaso cluster --help

    Ejemplos:
      elpaso model --help          # Ver ayuda del comando model
      elpaso --help             # Ver esta guía
      elpaso model add ...      # Añadir un modelo
    """)
  end

  def main(["model", "--help"]) do
    IO.puts("""
    ELPASO MODEL

    Gestión de modelos de inferencia.

    COMANDOS:

      elpaso model add          Añadir un nuevo modelo

    USO DEL COMANDO model add:

      elpaso model add [opciones]

    OPCIONES:

      --name <nombre>         Nombre único del modelo (REQUERIDO)
      --engine <engine>      ID o nombre del motor de inferencia (REQUERIDO)
      --url <url>          URL del endpoint de inferencia (REQUERIDO)
      --api-key <key>     API key para autenticación (opcional)
      --description <desc> Descripción del modelo (opcional)
      --active           Si el modelo está activo (default: true)
      --max-tokens <n>    Máximo número de tokens de salida (opcional)
      --temperature <t>   Temperatura default (default: 0.7)
      --top-p <p>         Top-p default (default: 1.0)

    EJEMPLOS:

      # Añadir modelo con motor llama.cpp
      elpaso model add \\
        --name llama-3-8b \\
        --engine llama-server \\
        --url http://localhost:8080/v1

      # Añadir modelo con motor vLLM (GPU optimizado)
      elpaso model add \\
        --name mixtral-8x7b \\
        --engine vllm-gpu \\
        --url http://localhost:8000/v1 \\
        --description "Modelo mixto optimizado" \\
        --max-tokens 32768

      # Añadir modelo con motor AirLLM (CPU optimizado)
      elpaso model add \\
        --name airllm-qwen \\
        --engine airllm \\
        --url http://localhost:8000/v1

      # Añadir modelo con motor Ollama (servidor externo)
      elpaso model add \\
        --name llama3-remote \\
        --engine ollama-remote \\
        --url http://192.168.1.100:11434/v1
    """)
  end

  def main(["engine", "--help"]) do
    IO.puts("""
    ELPASO ENGINE

    Gestión de motores de inferencia.

    COMANDOS:

      elpaso engine add         Añadir un nuevo motor

    USO DEL COMANDO engine add:

      elpaso engine add [opciones]

    OPCIONES:

      --name <nombre>       Nombre único del motor (REQUERIDO)
      --adapter <adapter>   Tipo de adaptador (REQUERIDO)
                         Valores válidos: openai, ollama, anthropic, vllm, llama, airllm
      --base-url <url>     URL base del motor (REQUERIDO)
      --api-key <key>     API key (opcional)
      --description <desc> Descripción del motor (opcional)
      --active            Si el motor está activo (default: true)
      --timeout <ms>      Timeout en milisegundos (default: 60000)

    ADAPTADORES DISPONIBLES:

      openai      OpenAI API compatible (api.openai.com)
      ollama     Ollama (localhost:11434)
      anthropic  Anthropic API (api.anthropic.com)
      vllm       vLLM API
      llama      Llama.cpp via servidor HTTP
      airllm     AirLLM

    EJEMPLOS:

      # Añadir motor llama.cpp (servidor HTTP local)
      elpaso engine add \\
        --name llama-server \\
        --adapter llama \\
        --base-url http://localhost:8080

      # Añadir motor vLLM (API GPU optimizada)
      elpaso engine add \\
        --name vllm-gpu \\
        --adapter vllm \\
        --base-url http://localhost:8000/v1

      # Añadir motor AirLLM (optimizado para CPU)
      elpaso engine add \\
        --name airllm \\
        --adapter airllm \\
        --base-url http://localhost:8000/v1

      # Añadir motor Ollama (servidor externo)
      elpaso engine add \\
        --name ollama-remote \\
        --adapter ollama \\
        --base-url http://192.168.1.100:11434/v1
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
      ["config" | rest] -> handle_config(rest)
      ["router" | rest] -> handle_router(rest)
      ["bench" | rest] -> handle_bench(rest)
      ["context" | rest] -> handle_context(rest)
      ["cluster" | rest] -> handle_cluster(rest)
      _ -> IO.puts("Comando desconocido. Usa 'elpaso --help' para ver los comandos disponibles.")
    end
  end

  # ==================== HANDLERS ====================

  defp handle_model(["add" | rest]) do
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
    handle_model(["add" | args])
  end

  defp handle_engine(["add" | rest]) do
    IO.puts("""
    Añadir motor de inferencia.

    Uso: elpaso engine add --name <name> --adapter <adapter> --base-url <url> [opciones]

    Оpciones detalladas en: elpaso engine --help
    """)
  end

  defp handle_engine([]) do
    IO.puts("Usa 'elpaso engine --help' para ver ayuda del comando engine.")
  end

  defp handle_engine(args) do
    handle_engine(["add" | args])
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
end