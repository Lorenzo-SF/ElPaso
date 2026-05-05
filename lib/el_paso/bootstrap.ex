defmodule ElPaso.Bootstrap do
  @moduledoc """
  Verificaciones pre-arranque para ElPaso v4.0 con soporte multi-modelo de embeddings.

  Secuencia de arranque:
    1. Verificar que Ollama está corriendo (Apero.Net)
    2. Detectar qué modelos de embeddings están disponibles
    3. Si no hay ninguno → preguntar al usuario cuál descargar
    4. Si elige bge-m3 → auto-configurar dimensión y regenerar embeddings
    5. Verificar PostgreSQL + pgvector

  Modelos soportados:
    - nomic-embed-text (274 MB, 768-dim) — default, ligero, multiidioma
    - bge-m3 (1.2 GB, 1024-dim) — SOTA multilingüe, más preciso
  """

  require Logger

  alias Apero.{Runner, Net, Proc, Helpers}

  @ollama_url "http://localhost:11434"
  @ollama_port 11434

  @models %{
    "nomic-embed-text" => %{size_mb: 274, dims: 768, desc: "Ligero (274 MB, 768-dim). Bueno para español/inglés."},
    "bge-m3" => %{size_mb: 1200, dims: 1024, desc: "SOTA multilingüe (1.2 GB, 1024-dim). Mejor precisión."}
  }

  @default_model "nomic-embed-text"

  # ═══════════════════════════════════════════════════════════════════════
  # PUBLIC API
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Ejecuta todas las verificaciones. Hace raise si algo es fatal."
  @spec run!() :: :ok
  def run! do
    Logger.info("[Bootstrap] Iniciando verificaciones pre-arranque...")

    verify_ollama!()
    model = ensure_embedding_model!()
    configure_model!(model)
    verify_database!()

    Logger.info("[Bootstrap] ✅ Todo listo. Modelo de embeddings: #{model}")
    :ok
  end

  # ═══════════════════════════════════════════════════════════════════════
  # 1. OLLAMA
  # ═══════════════════════════════════════════════════════════════════════

  defp verify_ollama! do
    Logger.info("[Bootstrap] Verificando Ollama...")

    unless Proc.command_exists?("ollama") do
      raise """
      ❌ 'ollama' no encontrado en el PATH.

      Instala Ollama:
        curl -fsSL https://ollama.com/install.sh | sh
      """
    end

    if Net.port_open?("localhost", @ollama_port) do
      Logger.info("[Bootstrap] ✅ Ollama detectado en localhost:#{@ollama_port}")
    else
      raise """
      ❌ Ollama no responde en localhost:#{@ollama_port}.

      Arranca el servicio:
        ollama serve
      """
    end

    :ok
  end

  # ═══════════════════════════════════════════════════════════════════════
  # 2. SELECCIÓN DE MODELO DE EMBEDDINGS
  # ═══════════════════════════════════════════════════════════════════════

  defp ensure_embedding_model! do
    configured = Application.get_env(:elpaso, :embedding_model, @default_model)

    # Si el usuario ya configuró un modelo específico, usarlo
    if configured != @default_model do
      ensure_model_downloaded!(configured)
      configured
    else
      # Auto-detección: ¿hay algún modelo ya descargado?
      available = detect_available_models()

      case available do
        [] ->
          # Ninguno descargado → preguntar al usuario
          prompt_model_selection()

        [model | _] ->
          # Al menos uno disponible → usarlo
          IO.puts("\n✅ Modelo de embeddings detectado: #{model} (#{@models[model].size_mb} MB)")
          ensure_model_downloaded!(model)
          model
      end
    end
  end

  defp detect_available_models do
    Map.keys(@models)
    |> Enum.filter(&model_available?/1)
  end

  defp prompt_model_selection do
    IO.puts("")
    IO.puts("╔══════════════════════════════════════════════════════════════╗")
    IO.puts("║  🤖 MODELO DE EMBEDDINGS                                   ║")
    IO.puts("║                                                              ║")
    IO.puts("║  ElPaso necesita un modelo de embeddings para el motor      ║")
    IO.puts("║  de decisiones semántico. No se ha detectado ninguno.       ║")
    IO.puts("╚══════════════════════════════════════════════════════════════╝")
    IO.puts("")

    # Construir opciones con descripción para mostrar,
    # pero guardar el mapping nombre → display_string
    model_list = Map.keys(@models)
    display_map = Map.new(@models, fn {name, info} ->
      {name, "#{name} — #{info.desc}"}
    end)
    display_options = Enum.map(model_list, &Map.fetch!(display_map, &1))

    choice =
      Helpers.question_with_options(
        "Elige el modelo de embeddings a descargar:",
        display_options
      )

    # Mapear la display string de vuelta al nombre del modelo
    selected =
      if choice do
        Enum.find(model_list, fn name -> Map.fetch!(display_map, name) == choice end)
      end

    case selected do
      nil ->
        IO.puts("Usando modelo por defecto: #{@default_model}")
        ensure_model_downloaded!(@default_model)
        @default_model

      model ->
        ensure_model_downloaded!(model)
        model
    end
  end

  defp ensure_model_downloaded!(model) do
    unless model_available?(model) do
      info = @models[model]
      IO.puts("")
      IO.puts("⬇  Descargando #{model} (#{info.size_mb} MB)...")
      IO.puts("   Esto solo ocurre la primera vez.")
      IO.puts("")

      case Runner.run("ollama", ["pull", model], timeout: 600_000) do
        {:ok, _output} ->
          IO.puts("✅ #{model} descargado correctamente.\n")
          Logger.info("[Bootstrap] ✅ #{model} descargado")

        {:error, output} ->
          raise """
          ❌ Error al descargar #{model}:
          #{output}

          Descárgalo manualmente:
            ollama pull #{model}
          """
      end
    end

    # Health check: verificar que genera embeddings con la dimensión correcta
    info = @models[model]
    case health_check_embedding(model, info.dims) do
      :ok ->
        Logger.info("[Bootstrap] ✅ Health check embeddings OK (#{info.dims}-dim)")

      {:error, reason} ->
        Logger.warning("[Bootstrap] ⚠️ Health check embeddings: #{inspect(reason)}")
    end

    :ok
  end

  # ═══════════════════════════════════════════════════════════════════════
  # 3. CONFIGURACIÓN AUTOMÁTICA
  # ═══════════════════════════════════════════════════════════════════════

  defp configure_model!(model) do
    info = @models[model]

    # Guardar en application env para que el resto de módulos lo usen
    Application.put_env(:elpaso, :embedding_model, model)
    Application.put_env(:elpaso, :embedding_dims, info.dims)

    # Si el modelo es distinto del default, guardar en archivo de config
    if model != @default_model do
      save_model_config(model)
    end

    :ok
  end

  defp save_model_config(model) do
    config_dir = Path.join(System.user_home!(), ".config/elpaso")
    config_file = Path.join(config_dir, "elpaso.conf")

    # Asegurar que el directorio existe (usando Apero.Pathy)
    File.mkdir_p!(config_dir)

    # Leer config existente o crear nuevo
    current =
      case File.read(config_file) do
        {:ok, content} -> content
        _ -> ""
      end

    # Añadir o actualizar sección [embeddings]
    new_config =
      if String.contains?(current, "[embeddings]") do
        String.replace(current, ~r/\[embeddings\][^\[]*/, "[embeddings]\nmodel = #{model}\n\n")
      else
        current <> "\n[embeddings]\nmodel = #{model}\n"
      end

    File.write!(config_file, new_config)

    IO.puts("⚙  Configuración guardada en #{config_file}")
    IO.puts("   Para regenerar embeddings de personalidades: mix elpaso personality embed")
    IO.puts("")
  end

  # ═══════════════════════════════════════════════════════════════════════
  # 4. POSTGRESQL + PGVECTOR
  # ═══════════════════════════════════════════════════════════════════════

  defp verify_database! do
    Logger.info("[Bootstrap] Verificando PostgreSQL + pgvector...")

    case ElPaso.Repo.query(
           "SELECT extname, extversion FROM pg_extension WHERE extname = 'vector'"
         ) do
      {:ok, %{num_rows: 1, rows: [["vector", version]]}} ->
        Logger.info("[Bootstrap] ✅ pgvector v#{version} detectado")

      {:ok, %{num_rows: 0}} ->
        raise """
        ❌ pgvector no está instalado en PostgreSQL.

        Instálalo:
          sudo apt install postgresql-14-pgvector
          psql -U postgres -d elpaso_dev -c "CREATE EXTENSION vector;"
        """

      {:error, reason} ->
        raise """
        ❌ No se pudo conectar a PostgreSQL: #{inspect(reason)}

        Verifica que PostgreSQL esté corriendo y la configuración en
        ~/.config/elpaso/elpaso.conf sea correcta.
        """
    end

    :ok
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HELPERS
  # ═══════════════════════════════════════════════════════════════════════

  defp model_available?(model_name) do
    url = "#{@ollama_url}/api/tags"

    case Finch.build(:get, url)
         |> Finch.request(ElPaso.Finch, receive_timeout: 5_000) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"models" => models}} ->
            Enum.any?(models, fn m ->
              name = m["name"] || ""
              String.starts_with?(name, model_name)
            end)

          _ ->
            false
        end

      _ ->
        false
    end
  end
