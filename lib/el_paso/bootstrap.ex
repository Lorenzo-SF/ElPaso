defmodule ElPaso.Bootstrap do
  @moduledoc """
  Verificaciones pre-arranque para ElPaso v4.0 con soporte multi-modelo de embeddings.

  Secuencia de arranque:
    1. Verificar PostgreSQL + pgvector (ANTES de descargar nada)
    2. Verificar que Ollama está corriendo
    3. Detectar qué modelos de embeddings están disponibles
    4. Si no hay ninguno → preguntar al usuario cuál descargar
    5. Si elige bge-m3 → auto-configurar dimensión
    6. Arranque completado

  Modelos soportados:
    - nomic-embed-text (274 MB, 768-dim) — default, ligero, multiidioma
    - bge-m3 (1.2 GB, 1024-dim) — SOTA multilingüe, más preciso
  """

  require Logger

  alias Apero.{Runner, Net, Proc, Helpers}

  @ollama_url "http://localhost:11434"
  @ollama_port 11_434
  @ollama_models_dir "~/.ollama/models"

  @models %{
    "nomic-embed-text" => %{size_mb: 274, dims: 768, desc: "Ligero (274 MB, 768-dim). Bueno para español/inglés."},
    "bge-m3" => %{size_mb: 1200, dims: 1024, desc: "SOTA multilingüe (1.2 GB, 1024-dim). Mejor precisión."}
  }

  @default_model "nomic-embed-text"

  # ═══════════════════════════════════════════════════════
  # PUBLIC API
  # ═══════════════════════════════════════════════════════

  @doc "Ejecuta todas las verificaciones. Hace raise si algo es fatal."
  @spec run!() :: :ok
  def run! do
    Logger.info("[Bootstrap] Iniciando verificaciones pre-arranque...")

    # 1. Base de datos — sin esto no tiene sentido seguir
    verify_database!()

    # 2. Ollama
    verify_ollama!()

    # 3-4. Embedding model
    model = ensure_embedding_model!()
    configure_model!(model)

    Logger.info("[Bootstrap] ✅ Todo listo. Modelo de embeddings: #{model}")
    :ok
  end

  # ═══════════════════════════════════════════════════════
  # 1. POSTGRESQL + PGVECTOR (primero, para no malgastar tiempo)
  # ═══════════════════════════════════════════════════════

  defp verify_database! do
    Logger.info("[Bootstrap] Verificando PostgreSQL + pgvector...")

    case ElPaso.Repo.query("SELECT extname, extversion FROM pg_extension WHERE extname = 'vector'") do
      {:ok, %{num_rows: 1, rows: [["vector", v]]}} ->
        Logger.info("[Bootstrap] ✅ pgvector v#{v} detectado")

      {:ok, %{num_rows: 0}} ->
        raise """
        ❌ pgvector no está instalado en PostgreSQL.

        PostgreSQL local:
          sudo apt install postgresql-14-pgvector
          psql -U postgres -d elpaso_dev -c "CREATE EXTENSION IF NOT EXISTS vector;"
          psql -U postgres -d elpaso_test -c "CREATE EXTENSION IF NOT EXISTS vector;"
          psql -U postgres -d elpaso_prod -c "CREATE EXTENSION IF NOT EXISTS vector;"

        PostgreSQL en Docker con localdocker:
          localdocker pgvector           # Instala pgvector SIN borrar datos (toca todas las BD)

        PostgreSQL en Docker genérico:
          docker exec -it <contenedor> bash -c "apt update && apt install -y postgresql-17-pgvector"
          docker exec -it <contenedor> psql -U postgres -d elpaso_dev -c "CREATE EXTENSION vector;"
        """

      {:error, reason} ->
        raise """
        ❌ No se pudo conectar a PostgreSQL: #{inspect(reason)}

        Verifica que PostgreSQL esté corriendo:
          Docker: localdocker status
          Local:  sudo systemctl status postgresql
        """
    end

    :ok
  end

  # ═══════════════════════════════════════════════════════
  # 2. OLLAMA
  # ═══════════════════════════════════════════════════════

  defp verify_ollama! do
    Logger.info("[Bootstrap] Verificando Ollama...")

    unless Proc.command_exists?("ollama") do
      raise "❌ 'ollama' no encontrado en el PATH.\nInstálalo: curl -fsSL https://ollama.com/install.sh | sh"
    end

    if Net.port_open?("localhost", @ollama_port) do
      Logger.info("[Bootstrap] ✅ Ollama detectado en localhost:#{@ollama_port}")
    else
      raise "❌ Ollama no responde en localhost:#{@ollama_port}.\nArranca el servicio: ollama serve"
    end

    :ok
  end

  # ═══════════════════════════════════════════════════════
  # 3. SELECCIÓN DE MODELO DE EMBEDDINGS
  # ═══════════════════════════════════════════════════════

  defp ensure_embedding_model! do
    configured = Application.get_env(:elpaso, :embedding_model, @default_model)

    if configured != @default_model do
      ensure_model_downloaded!(configured)
      configured
    else
      available = detect_available_models()

      if available == [] do
        prompt_model_selection()
      else
        model = hd(available)
        IO.puts("\n✅ Modelo de embeddings detectado: #{model} (#{@models[model].size_mb} MB)")
        ensure_model_downloaded!(model)
        model
      end
    end
  end

  defp detect_available_models do
    Map.keys(@models) |> Enum.filter(&model_available?/1)
  end

  defp prompt_model_selection do
    IO.puts("""

    ╔══════════════════════════════════════════════════════════════╗
    ║  🤖 MODELO DE EMBEDDINGS                                   ║
    ║                                                              ║
    ║  ElPaso necesita un modelo de embeddings para el motor      ║
    ║  de decisiones semántico. No se ha detectado ninguno.       ║
    ║                                                              ║
    ║  Los modelos se descargan via Ollama en:                    ║
    ║  #{String.pad_trailing(@ollama_models_dir, 52)}║
    ╚══════════════════════════════════════════════════════════════╝
    """)

    model_list = [@default_model | (Map.keys(@models) -- [@default_model])]

    display_map =
      Map.new(@models, fn {name, info} -> {name, "#{name} — #{info.desc}"} end)

    display_options = Enum.map(model_list, &Map.fetch!(display_map, &1))

    choice = Helpers.question_with_options("Elige el modelo de embeddings a descargar:", display_options)

    selected =
      if choice, do: Enum.find(model_list, fn n -> Map.fetch!(display_map, n) == choice end)

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
      IO.puts("\n⬇  Descargando #{model} (#{info.size_mb} MB) via Ollama...")
      IO.puts("   Ruta: #{@ollama_models_dir}")
      IO.puts("   Esto solo ocurre la primera vez.\n")

      case Runner.run("ollama", ["pull", model]) do
        {:ok, _output} ->
          IO.puts("✅ #{model} descargado correctamente.\n")
          Logger.info("[Bootstrap] ✅ #{model} descargado")

        {:error, output} ->
          raise """
          ❌ Error al descargar #{model}:
          #{inspect(output)}

          Descárgalo manualmente:
            ollama pull #{model}
          """
      end
    end

    info = @models[model]
    case health_check_embedding(model, info.dims) do
      :ok -> Logger.info("[Bootstrap] ✅ Health check embeddings OK (#{info.dims}-dim)")
      {:error, r} -> Logger.warning("[Bootstrap] ⚠️ Health check: #{inspect(r)}")
    end

    :ok
  end

  # ═══════════════════════════════════════════════════════
  # 4. CONFIGURACIÓN AUTOMÁTICA
  # ═══════════════════════════════════════════════════════

  defp configure_model!(model) do
    info = @models[model]
    Application.put_env(:elpaso, :embedding_model, model)
    Application.put_env(:elpaso, :embedding_dims, info.dims)
    if model != @default_model, do: save_model_config(model)
    :ok
  end

  defp save_model_config(model) do
    config_dir = Path.join(System.user_home!(), ".config/elpaso")
    config_file = Path.join(config_dir, "elpaso.conf")
    File.mkdir_p!(config_dir)

    current = case File.read(config_file) do
      {:ok, c} -> c
      _ -> ""
    end

    new_config =
      if String.contains?(current, "[embeddings]") do
        String.replace(current, ~r/\[embeddings\][^\[]*/, "[embeddings]\nmodel = #{model}\n\n")
      else
        current <> "\n[embeddings]\nmodel = #{model}\n"
      end

    File.write!(config_file, new_config)
    IO.puts("⚙  Configuración guardada en #{config_file}")
    IO.puts("   Para regenerar embeddings de personalidades: mix elpaso personality embed")
    IO.puts("   Para borrar el modelo: ollama rm #{model}")
    IO.puts("   Ruta de modelos Ollama: #{@ollama_models_dir}\n")
  end

  # ═══════════════════════════════════════════════════════
  # HELPERS
  # ═══════════════════════════════════════════════════════

  defp model_available?(model_name) do
    case Finch.build(:get, "#{@ollama_url}/api/tags")
         |> Finch.request(ElPaso.Finch, receive_timeout: 5_000) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"models" => models}} ->
            Enum.any?(models, fn m -> String.starts_with?(m["name"] || "", model_name) end)
          _ -> false
        end
      _ -> false
    end
  end

  defp health_check_embedding(model_name, expected_dims) do
    body = Jason.encode!(%{model: model_name, prompt: "elpaso health check"})
    headers = [{"content-type", "application/json"}]

    case Finch.build(:post, "#{@ollama_url}/api/embeddings", headers, body)
         |> Finch.request(ElPaso.Finch, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"embedding" => e}} when is_list(e) ->
            if length(e) == expected_dims, do: :ok, else: {:error, "dim mismatch: #{length(e)} vs #{expected_dims}"}
          {:ok, o} -> {:error, "unexpected: #{inspect(o)}"}
          {:error, r} -> {:error, "JSON: #{inspect(r)}"}
        end
      {:ok, %{status: s}} -> {:error, "HTTP #{s}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end
end
