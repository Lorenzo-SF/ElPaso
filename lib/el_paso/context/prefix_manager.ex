defmodule ElPaso.Context.PrefixManager do
  @moduledoc """
  Caché de system prompts pre-construidos (el "prefix" que se antepone
  a los mensajes del usuario en cada inferencia).

  ## Propósito

  Cuando una misma personalidad se usa repetidamente dentro de una sesión,
  el system prompt (personalidad + contexto de sesión + knowledge board)
  no cambia entre peticiones. Reconstruirlo cada vez es innecesario.

  Este módulo cachea en ETS el system prompt completo por tupla
  `{personality_name, session_context_hash}`, reduciendo el trabajo
  de `ContextBuilder` cuando no hay cambios en el contexto.

  ## TTL

  Los system prompts cacheados expiran tras 10 minutos por defecto.
  Si el contexto de sesión cambia (nuevo conocimiento, cambio de resumen),
  la entrada se invalida automáticamente.

  ## Uso

      # Guardar un system prompt construido
      PrefixManager.put("coder", session_hash, full_system_prompt)

      # Recuperar (si existe y no expiró)
      PrefixManager.get("coder", session_hash)
      # => {:ok, "You are a coding expert..."} o :miss
  """

  use GenServer
  require Logger

  @table :prefix_cache
  @default_ttl_ms 600_000  # 10 minutos
  @cleanup_interval_ms 300_000  # 5 minutos

  # ── Client API ────────────────────────────────────────────────────────────

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
  Guarda un system prompt en la caché.

  `key` = `{personality_name, session_context_hash}`.
  El TTL se aplica a nivel de entrada.
  """
  @spec put(String.t(), String.t(), String.t(), pos_integer()) :: :ok
  def put(personality_name, context_hash, system_prompt, ttl_ms \\ @default_ttl_ms) do
    key = cache_key(personality_name, context_hash)
    expires_at = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(@table, {key, system_prompt, expires_at})
    :ok
  end

  @doc """
  Recupera un system prompt de la caché.

  Devuelve `{:ok, system_prompt}` si existe y no ha expirado,
  o `:miss` en caso contrario.
  """
  @spec get(String.t(), String.t()) :: {:ok, String.t()} | :miss
  def get(personality_name, context_hash) do
    key = cache_key(personality_name, context_hash)
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, key) do
      [{^key, system_prompt, expires_at}] when expires_at > now ->
        {:ok, system_prompt}

      [{^key, _system_prompt, _expires_at}] ->
        # Expirado — eliminarlo
        :ets.delete(@table, key)
        :miss

      [] ->
        :miss
    end
  end

  @doc """
  Invalida todas las entradas para una personalidad concreta.
  Útil cuando cambia el system prompt de la personalidad.
  """
  @spec invalidate_personality(String.t()) :: :ok
  def invalidate_personality(personality_name) do
    match_pattern = {{personality_name, :_}, :_, :_}
    :ets.match_delete(@table, match_pattern)
    Logger.debug("[PrefixManager] Invalidada caché para '#{personality_name}'")
    :ok
  end

  @doc """
  Invalida todas las entradas para una sesión concreta.
  Útil cuando el contexto de sesión cambia significativamente.
  """
  @spec invalidate_session(String.t()) :: :ok
  def invalidate_session(context_hash) do
    match_pattern = {{:_, context_hash}, :_, :_}
    :ets.match_delete(@table, match_pattern)
    Logger.debug("[PrefixManager] Invalidada caché para session hash '#{context_hash}'")
    :ok
  end

  @doc "Limpia todas las entradas expiradas."
  @spec cleanup() :: non_neg_integer()
  def cleanup do
    now = System.monotonic_time(:millisecond)

    expired =
      :ets.select(@table, [{{:"$1", :"$2", :"$3"}, [{:<, :"$3", now}], [:"$1"]}])

    Enum.each(expired, &:ets.delete(@table, &1))
    length(expired)
  end

  @doc "Número de entradas en caché."
  @spec size() :: non_neg_integer()
  def size do
    :ets.info(@table, :size)
  end

  @doc "Estadísticas de la caché."
  @spec stats() :: map()
  def stats do
    %{
      size: size(),
      memory_words: :ets.info(@table, :memory),
      table_type: :ets.info(@table, :type)
    }
  end

  # ── Server Callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(_) do
    init()
    schedule_cleanup()
    Logger.info("[PrefixManager] Inicializado. ETS table: #{inspect(@table)}")
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    n = cleanup()

    if n > 0 do
      Logger.debug("[PrefixManager] Limpiadas #{n} entradas expiradas.")
    end

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  defp cache_key(personality_name, context_hash) do
    {personality_name, context_hash}
  end
end
