defmodule ElPaso.CostManagerTest do
  use ElPaso.DataCase, async: false

  alias ElPaso.CostManager

  describe "get_price/1" do
    test "returns pricing for opus models" do
      price = CostManager.get_price("claude-3-opus")
      assert Decimal.to_float(price.input_price_per_1k) == 15.0
      assert Decimal.to_float(price.output_price_per_1k) == 75.0
    end

    test "returns pricing for sonnet models" do
      price = CostManager.get_price("claude-3-sonnet")
      assert Decimal.to_float(price.input_price_per_1k) == 3.0
      assert Decimal.to_float(price.output_price_per_1k) == 15.0
    end

    test "returns pricing for haiku models" do
      price = CostManager.get_price("claude-3-haiku")
      assert Decimal.to_float(price.input_price_per_1k) == 0.25
      assert Decimal.to_float(price.output_price_per_1k) == 1.25
    end

    test "returns default pricing for unknown models" do
      price = CostManager.get_price("unknown-model")
      assert Decimal.to_float(price.input_price_per_1k) == 1.0
      assert Decimal.to_float(price.output_price_per_1k) == 5.0
    end
  end

  describe "calculate_cost/3" do
    test "calculates cost correctly" do
      price = %{
        input_price_per_1k: Decimal.from_float(1.0),
        output_price_per_1k: Decimal.from_float(5.0)
      }

      cost = CostManager.calculate_cost(1000, 1000, price)
      assert Decimal.to_float(cost) == 6.0
    end

    test "calculates zero cost for zero tokens" do
      price = %{
        input_price_per_1k: Decimal.from_float(1.0),
        output_price_per_1k: Decimal.from_float(5.0)
      }

      cost = CostManager.calculate_cost(0, 0, price)
      assert Decimal.to_float(cost) == 0.0
    end
  end

  describe "check_budget/1" do
    test "returns ok when cost management disabled" do
      assert :ok = CostManager.check_budget("user-1")
    end
  end

  describe "remote_model_penalty/1" do
    test "returns a float penalty" do
      assert is_float(CostManager.remote_model_penalty("user-1"))
    end
  end

  describe "record_usage/4" do
    test "records usage successfully" do
      assert :ok = CostManager.record_usage("user-test", "gpt-4", 100, 50)
    end
  end
end
