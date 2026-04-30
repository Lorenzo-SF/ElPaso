defmodule ElPaso.CostManagerTest do
  @moduledoc """
  Tests para ElPaso.CostManager.
  """

  use ElPaso.DataCase, async: true

  alias ElPaso.CostManager
  alias ElPaso.Context.Storage

  describe "calculate_cost/3" do
    test "calcula coste para tokens dados" do
      price = %{
        input_price_per_1k: Decimal.from_float(1.0),
        output_price_per_1k: Decimal.from_float(5.0)
      }

      cost = CostManager.calculate_cost(1000, 1000, price)
      assert Decimal.to_float(cost) == 6.0
    end

    test "devuelve 0 para 0 tokens" do
      price = %{
        input_price_per_1k: Decimal.from_float(1.0),
        output_price_per_1k: Decimal.from_float(5.0)
      }

      cost = CostManager.calculate_cost(0, 0, price)
      assert Decimal.to_float(cost) == 0.0
    end
  end

  describe "get_price/1" do
    test "devuelve pricing por defecto para modelos desconocidos" do
      price = CostManager.get_price("unknown-model")
      assert Decimal.to_float(price.input_price_per_1k) == 1.0
      assert Decimal.to_float(price.output_price_per_1k) == 5.0
    end

    test "devuelve pricing específico para modelos anthropic" do
      opus = CostManager.get_price("claude-3-opus")
      assert Decimal.to_float(opus.input_price_per_1k) == 15.0

      haiku = CostManager.get_price("claude-3-haiku")
      assert Decimal.to_float(haiku.input_price_per_1k) == 0.25
    end
  end

  describe "record_usage/4" do
    test "registra uso de tokens" do
      assert :ok = CostManager.record_usage("user-1", "gpt-4", 100, 50)
    end
  end

  describe "check_budget/1" do
    test "devuelve :ok cuando cost management está deshabilitado" do
      assert :ok = CostManager.check_budget("user-1")
    end
  end

  describe "remote_model_penalty/1" do
    test "devuelve 0.0 cuando el budget está ok" do
      assert 0.0 = CostManager.remote_model_penalty("user-1")
    end
  end
end
