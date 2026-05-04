defmodule ElPaso.Security.RateLimiterTest do
  use ExUnit.Case, async: false

  alias ElPaso.Security.RateLimiter

  setup do
    RateLimiter.init()
    :ok
  end

  describe "check_rate/2" do
    test "primer request es aceptado" do
      assert :ok = RateLimiter.check_rate("user_1", 5)
    end

    test "requests dentro del límite son aceptados" do
      assert :ok = RateLimiter.check_rate("user_2", 5)
      assert :ok = RateLimiter.check_rate("user_2", 5)
      assert :ok = RateLimiter.check_rate("user_2", 5)
      assert :ok = RateLimiter.check_rate("user_2", 5)
      assert :ok = RateLimiter.check_rate("user_2", 5)
    end

    test "requests que exceden el límite son rechazados" do
      assert :ok = RateLimiter.check_rate("user_3", 2)
      assert :ok = RateLimiter.check_rate("user_3", 2)
      assert {:error, :rate_limited} = RateLimiter.check_rate("user_3", 2)
    end

    test "diferentes usuarios tienen buckets independientes" do
      assert :ok = RateLimiter.check_rate("user_a", 1)
      assert {:error, :rate_limited} = RateLimiter.check_rate("user_a", 1)
      assert :ok = RateLimiter.check_rate("user_b", 1)
    end
  end
end
