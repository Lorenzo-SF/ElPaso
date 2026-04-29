defmodule ElPaso.Security.RateLimiterTest do
  @moduledoc """
  Tests para ElPaso.Security.RateLimiter.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Security.RateLimiter

  setup do
    RateLimiter.init()
    :ok
  end

  describe "check_rate/2" do
    test "permite requests dentro del límite" do
      assert :ok = RateLimiter.check_rate("user-1", 60)
      assert :ok = RateLimiter.check_rate("user-1", 60)
    end

    test "limita requests excesivos" do
      # Agotar el bucket
      for _ <- 1..60 do
        RateLimiter.check_rate("user-2", 60)
      end

      # El siguiente debe ser limitado
      assert {:error, :rate_limited} = RateLimiter.check_rate("user-2", 60)
    end
  end

  describe "init/0" do
    test "inicializa el rate limiter" do
      assert :rate_limiter in :ets.all()
    end
  end
end
