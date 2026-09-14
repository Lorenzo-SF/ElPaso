defmodule ElPaso.Domain.DecisionEngine.DecisionCache do
  @moduledoc """
  Caché en ETS para decisiones de routing.

  Evita re-evaluar el mismo prompt exacto en el DecisionEngine.
  Hash SHA256 del contenido → nombre de personalidad elegida.

  TTL: 5 minutos por defecto (configurable).
  """


  @table :routing_decision_cache
  @default_ttl_ms 300_000

  @doc "Inicializa la tabla ETS de caché."
  @spec init() :: :ets.tid()
  def init do
    case :ets.info(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

      _ ->
        @table
    end
  end

  @doc """
  Busca una decisión en caché.

  Devuelve:
    - {:hit, personality_name} si existe y no ha expirado
    - :miss si no existe o expiró
  """
  @spec get(String.t()) :: {:hit, String.t()} | :miss
  def get(content) do
    hash = hash_content(content)

    case :ets.lookup(@table, hash) do
      [{^hash, personality_name, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:hit, personality_name}
        else
          :ets.delete(@table, hash)
          :miss
        end

      [] ->
        :miss
    end
  end

  @doc """
  Almacena una decisión en caché.

  Argumentos:
    - content: el contenido del prompt del usuario
    - personality_name: la personalidad elegida
    - ttl_ms: tiempo de vida en milisegundos (default 5 min)
  """
  @spec put(String.t(), String.t(), integer()) :: :ok
  def put(content, personality_name, ttl_ms \\ @default_ttl_ms) do
    hash = hash_content(content)
    expires_at = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(@table, {hash, personality_name, expires_at})
    :ok
  end

  @doc "Limpia todas las entradas de la caché."
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc "Devuelve el número de entradas en caché."
  @spec size() :: non_neg_integer()
  def size do
    case :ets.info(@table) do
      :undefined -> 0
      info -> Keyword.get(info, :size, 0)
    end
  end

  defp hash_content(content) do
    ElPaso.Ecosystem.crypto_hash(:sha256, String.downcase(content)) || :erlang.phash2(content)
  end
end
