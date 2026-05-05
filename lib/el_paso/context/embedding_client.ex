defmodule ElPaso.Context.EmbeddingClient do
  @moduledoc """
  Cliente para generar embeddings de texto usando Ollama.

  El modelo de embeddings es configurable (nomic-embed-text o bge-m3).
  La verificación y descarga automática ocurren en ElPaso.Bootstrap al arrancar.

  Caché en ETS para no re-generar embeddings idénticos.
  TTL de caché: 1 hora (configurable).
  """

  use GenServer
  require Logger

  alias Apero.Crypto

  @cache_table :embedding_cache
  @default_model "nomic-embed-text"
  @default_dims 768
  @default_url "http://localhost:11434/api/embeddings"

  # ── Client API ──────────────────────────────────────────────────────────

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc "Genera embedding para un texto. Usa caché ETS con TTL."
  @spec embed(String.t()) :: {:ok, [float()]} | {:error, term()}
  def embed(text) when is_binary(text) do
    cache_key = Crypto.hash(text, :sha256)

    case :ets.lookup(@cache_table, cache_key) do
      [{^cache_key, embedding, expires_at}] ->
        if System.monotonic_time(:second) < expires_at do
          {:ok, embedding}
        else
          :ets.delete(@cache_table, cache_key)
          GenServer.call(__MODULE__, {:embed, text, cache_key})
        end

      [] ->
        GenServer.call(__MODULE__, {:embed, text, cache_key})
    end
  end

  @doc """
  Verifica que el modelo de embeddings responde correctamente.
  Usado por ElPaso.Bootstrap durante el arranque.
  """
  @spec health_check() :: :ok | {:error, term()}
  def health_check do
    expected = get_dims()

    case embed("elpaso health check") do
      {:ok, embedding} when is_list(embedding) ->
        if length(embedding) == expected do
          :ok
        else
          {:error, "dimension mismatch: got #{length(embedding)}, expected #{expected}"}
        end

      {:ok, other} ->
        {:error, "unexpected response: #{inspect(other)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Server ──────────────────────────────────────────────────────────────

  @impl true
  def init(_) do
    :ets.new(@cache_table, [:named_table, :public, :set, read_concurrency: true])
    Logger.info("[EmbeddingClient] Inicializado. Modelo: #{get_model_name()} (#{get_dims()}-dim)")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:embed, text, cache_key}, _from, state) do
    ttl = Application.get_env(:elpaso, :embedding_cache_ttl_sec, 3600)
    expires_at = System.monotonic_time(:second) + ttl
    expected = get_dims()

    case do_embed(text) do
      {:ok, embedding} when is_list(embedding) ->
        if length(embedding) == expected do
          :ets.insert(@cache_table, {cache_key, embedding, expires_at})
          {:reply, {:ok, embedding}, state}
        else
          Logger.error("[EmbeddingClient] Dimension mismatch: #{length(embedding)} (expected #{expected})")
          {:reply, {:error, :dimension_mismatch}, state}
        end

      {:error, reason} ->
        Logger.warning("[EmbeddingClient] Embedding failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  defp do_embed(text) do
    case embed_via_ollama(text) do
      {:ok, embedding} -> {:ok, embedding}
      {:error, _} -> embed_via_openai(text)
    end
  end

  defp embed_via_ollama(text) do
    url = get_url()
    model = get_model_name()

    body = Jason.encode!(%{model: model, prompt: text})
    headers = [{"content-type", "application/json"}]

    case Finch.build(:post, url, headers, body)
         |> Finch.request(ElPaso.Finch, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"embedding" => embedding}} when is_list(embedding) ->
            {:ok, embedding}

          {:ok, other} ->
            {:error, "unexpected ollama response: #{inspect(other)}"}

          {:error, reason} ->
            {:error, "JSON decode error: #{inspect(reason)}"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp embed_via_openai(text) do
    api_key = Application.get_env(:elpaso, :openai_api_key)
    if api_key do
      url = "https://api.openai.com/v1/embeddings"
      body = Jason.encode!(%{model: "text-embedding-3-small", input: text})
      headers = [
        {"content-type", "application/json"},
        {"authorization", "Bearer #{api_key}"}
      ]
      case Finch.build(:post, url, headers, body)
           |> Finch.request(ElPaso.Finch, receive_timeout: 30_000) do
        {:ok, %{status: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"data" => [%{"embedding" => embedding} | _]}} -> {:ok, embedding}
            _ -> {:error, "unexpected openai response"}
          end
        error -> {:error, "openai embedding failed: #{inspect(error)}"}
      end
    else
      {:error, :no_embedding_provider_available}
    end
  end

  defp get_model_name, do: Application.get_env(:elpaso, :embedding_model, @default_model)
  defp get_dims, do: Application.get_env(:elpaso, :embedding_dims, @default_dims)
  defp get_url, do: Application.get_env(:elpaso, :embedding_url, @default_url)
end
