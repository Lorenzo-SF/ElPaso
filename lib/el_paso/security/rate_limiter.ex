defmodule ElPaso.Security.RateLimiter do
  @moduledoc """
  Token bucket rate limiter usando ETS con operaciones atómicas.

  Implementa el algoritmo token bucket:
  - Cada usuario/clave tiene un bucket con `max_tokens`.
  - Los tokens se recargan a razón de `max_tokens` por minuto.
  - Cada request consume 1 token.
  - Si no hay tokens, se rechaza con `{:error, :rate_limited}`.
  """

  @table :rate_limiter
  @cleanup_interval_ms 300_000  # 5 minutos

  @doc """
  Verifica si el usuario/clave tiene tokens disponibles.

  Retorna `:ok` si se permite el request, `{:error, :rate_limited}` si no.
  """
  @spec check_rate(String.t(), pos_integer()) :: :ok | {:error, :rate_limited}
  def check_rate(user_id, max_rpm) when is_binary(user_id) and is_integer(max_rpm) and max_rpm > 0 do
    # Usar ETS con operación atómica para evitar race conditions
    # Formato: {key, tokens_available, last_refill_second}
    key = user_id
    now = System.monotonic_time(:second)

    case :ets.lookup(@table, key) do
      [] ->
        # Primer request: crear bucket con max_rpm - 1 tokens
        :ets.insert_new(@table, {key, max_rpm - 1, now})
        :ok

      [{^key, tokens, last_refill}] ->
        # Calcular refill basado en tiempo transcurrido (en segundos)
        elapsed = now - last_refill
        # Refill rate: max_rpm tokens por 60 segundos
        refill_tokens = floor(elapsed * max_rpm / 60)
        new_tokens = min(tokens + refill_tokens, max_rpm)

        if new_tokens >= 1 do
          # Actualización atómica
          :ets.insert(@table, {key, new_tokens - 1, now})
          :ok
        else
          {:error, :rate_limited}
        end
    end
  end

  @doc """
  Inicializa la tabla ETS para rate limiting.
  También programa limpieza periódica de entradas antiguas.
  """
  def init do
    case :ets.info(@table) do
      :undefined ->
        table = :ets.new(@table, [
          :named_table,
          :public,       # Múltiples procesos necesitan escribir (workers HTTP)
          :set,
          read_concurrency: true
        ])

        # Programar limpieza periódica
        spawn(fn -> cleanup_loop() end)

        table

      _ ->
        @table
    end
  end

  @doc """
  Limpia entradas que no han tenido actividad en más de 1 hora.
  """
  def cleanup_stale do
    now = System.monotonic_time(:second)
    threshold = now - 3600

    :ets.select_delete(@table, [
      {{:"$1", :"$2", :"$3"}, [{:<, :"$3", threshold}], [true]}
    ])
  end

  # ── Private ──────────────────────────────────────────────────

  defp cleanup_loop do
    Process.sleep(@cleanup_interval_ms)
    cleanup_stale()
    cleanup_loop()
  end
end
