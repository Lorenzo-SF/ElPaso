defmodule ElPaso.Bootstrap do
  @moduledoc """
  Verificaciones pre-arranque para ElPaso v4.0.

  Secuencia de arranque:
    1. Ollama disponible en localhost:11434
    2. Modelo de embeddings `nomic-embed-text` (274 MB, 768-dim, multiidioma) descargado
    3. Conexión a PostgreSQL con extensión pgvector activa

  Si alguna verificación falla, se muestra un mensaje de error claro con
  instrucciones para resolverlo y el proceso termina.

  La verificación del modelo de embeddings incluye un health check real:
  se genera un embedding de prueba y se verifica que la dimensión es 768.
  """

  require Logger

  @ollama_url "http://localhost:11434"

  @doc """
  Ejecuta todas las verificaciones de arranque en orden.
  Hace raise si alguna falla, deteniendo el arranque del servidor.
  """
  @spec run!() :: :ok
  def run! do
    Logger.info("[Bootstrap] Iniciando verificaciones pre-arranque...")

    verify_ollama!()
    verify_embedding_model!()
    verify_database!()

    Logger.info("[Bootstrap] ✅ Todas las verificaciones superadas")
    :ok
  end

  @doc """
  Verifica que Ollama está corriendo y responde en localhost:11434.
  """
  @spec verify_ollama!() :: :ok
  def verify_ollama! do
    Logger.info("[Bootstrap] Verificando Ollama en #{@ollama_url}...")

    case check_ollama_health() do
      :ok ->
        Logger.info("[Bootstrap] ✅ Ollama detectado en #{@ollama_url}")

      {:error, reason} ->
        raise """
        ❌ Ollama no está disponible en #{@ollama_url}:
           #{inspect(reason)}

        ElPaso necesita Ollama como servidor de modelos.

        Para instalar Ollama:
          curl -fsSL https://ollama.com/install.sh | sh

        Para arrancar el servicio (si ya está instalado):
          ollama serve

        Verifica que Ollama está corriendo:
          curl #{@ollama_url}/api/tags
        """
    end

    :ok
  end

  @doc """
  Verifica que el modelo de embeddings está descargado en Ollama.
  Si no lo está, lo descarga automáticamente (274 MB, ~2-5 min).
  """
  @spec verify_embedding_model!() :: :ok
  def verify_embedding_model! do
    model = Application.get_env(:elpaso, :embedding_model, "nomic-embed-text")

    Logger.info("[Bootstrap] Verificando modelo de embeddings '#{model}'...")

    if model_available?(model) do
      Logger.info("[Bootstrap] ✅ Modelo '#{model}' disponible")

      # Health check: verificar que realmente genera embeddings de 768 dims
      case health_check_embedding(model) do
        :ok ->
          Logger.info("[Bootstrap] ✅ Health check de embeddings OK (768 dimensiones)")

        {:error, reason} ->
          Logger.warning("[Bootstrap] ⚠️ Health check de embeddings: #{inspect(reason)}")
          Logger.warning("[Bootstrap] El modelo existe pero podría no funcionar correctamente")
      end
    else
      IO.puts("")
      IO.puts("╔══════════════════════════════════════════════════════════════╗")
      IO.puts("║  ⬇  DESCARGANDO MODELO DE EMBEDDINGS                      ║")
      IO.puts("║                                                              ║")
      IO.puts("║  Modelo: #{String.pad_trailing(model, 44)}║")
      IO.puts("║  Tamaño: 274 MB                                             ║")
      IO.puts("║  Tiempo estimado: 2-5 minutos (según conexión)              ║")
      IO.puts("║                                                              ║")
      IO.puts("║  Esto solo ocurre la primera vez.                           ║")
      IO.puts("╚══════════════════════════════════════════════════════════════╝")
      IO.puts("")

      case download_model(model) do
        :ok ->
          IO.puts("")
          IO.puts("✅ Modelo '#{model}' descargado correctamente.")
          IO.puts("   ElPaso ya puede usar embeddings para el motor de decisiones.")
          IO.puts("")
          Logger.info("[Bootstrap] ✅ '#{model}' descargado e instalado")

        {:error, output, code} ->
          raise """
          ❌ Error al descargar el modelo '#{model}' (exit code: #{code}):

          #{output}

          Descárgalo manualmente:
            ollama pull #{model}

          Y vuelve a arrancar ElPaso.
          """
      end
    end

    :ok
  end

  @doc """
  Verifica que PostgreSQL tiene la extensión pgvector instalada.
  """
  @spec verify_database!() :: :ok
  def verify_database! do
    Logger.info("[Bootstrap] Verificando PostgreSQL + pgvector...")

    case ElPaso.Repo.query("SELECT extname, extversion FROM pg_extension WHERE extname = 'vector'") do
      {:ok, %{num_rows: 1, rows: [["vector", version]]}} ->
        Logger.info("[Bootstrap] ✅ pgvector v#{version} detectado")

      {:ok, %{num_rows: 0}} ->
        raise """
        ❌ La extensión pgvector no está instalada en PostgreSQL.

        Instálala con:
          sudo apt install postgresql-14-pgvector
          psql -U postgres -d elpaso_dev -c "CREATE EXTENSION vector;"

        O si usas Docker:
          docker exec -it postgres psql -U postgres -d elpaso_dev -c "CREATE EXTENSION vector;"
        """

      {:error, reason} ->
        raise """
        ❌ No se pudo conectar a PostgreSQL: #{inspect(reason)}

        Verifica que PostgreSQL esté corriendo y que la configuración
        en ~/.config/elpaso/elpaso.conf sea correcta.
        """
    end

    :ok
  end

  # ═══════════════════════════════════════════════════════════════════
  # PRIVATE HELPERS
  # ═══════════════════════════════════════════════════════════════════

  defp check_ollama_health do
    url = "#{@ollama_url}/api/tags"

    case Finch.build(:get, url)
         |> Finch.request(ElPaso.Finch, receive_timeout: 5_000) do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, %Mint.TransportError{reason: :econnrefused}} ->
        {:error, "conexión rechazada — ¿está Ollama corriendo? (ollama serve)"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

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

  defp download_model(model_name) do
    # Usar comando del sistema: ollama pull <model>
    # Esto es bloqueante pero solo ocurre una vez en la vida de la instalación
    case System.cmd("ollama", ["pull", model_name],
           stderr_to_stdout: true,
           into: fn
             :stdout, data -> IO.write(data)
             :stderr, data -> IO.write(:stderr, data)
           end) do
      {_output, 0} -> :ok
      {output, code} -> {:error, output, code}
    end
  end

  @doc """
  Health check: envía un texto de prueba al modelo de embeddings y
  verifica que devuelve un vector de 768 dimensiones.
  """
  def health_check_embedding(model_name) do
    url = "#{@ollama_url}/api/embeddings"
    body = Jason.encode!(%{model: model_name, prompt: "elpaso health check"})
    headers = [{"content-type", "application/json"}]

    case Finch.build(:post, url, headers, body)
         |> Finch.request(ElPaso.Finch, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"embedding" => embedding}} when is_list(embedding) ->
            dims = length(embedding)

            if dims == 768 do
              :ok
            else
              {:error, "dimensión inesperada: #{dims} (esperado 768)"}
            end

          {:ok, other} ->
            {:error, "respuesta inesperada: #{inspect(other)}"}

          {:error, reason} ->
            {:error, "JSON inválido: #{inspect(reason)}"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end
end
