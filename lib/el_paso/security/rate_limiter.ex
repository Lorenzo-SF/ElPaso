defmodule ElPaso.Security.RateLimiter do
  # Token bucket por user_id en ETS
  # Tabla ETS: {user_id, tokens_available, last_refill_at}

  def check_rate(user_id, max_rpm) do
    now = System.monotonic_time(:second)
    key = {__MODULE__, user_id}

    case :ets.lookup(:rate_limiter, key) do
      [] ->
        :ets.insert(:rate_limiter, {key, max_rpm - 1, now})
        :ok

      [{^key, tokens, last_refill}] ->
        elapsed_minutes = (now - last_refill) / 60
        refilled = min(max_rpm, tokens + elapsed_minutes * max_rpm)

        if refilled >= 1 do
          :ets.insert(:rate_limiter, {key, refilled - 1, now})
          :ok
        else
          {:error, :rate_limited}
        end
    end
  end

  def init() do
    :ets.new(:rate_limiter, [:named_table, :public, :set])
  end
end
