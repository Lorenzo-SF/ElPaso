defmodule ElPaso.Context.BuilderTest do
  @moduledoc """
  Tests para ElPaso.Context.Builder.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Context.Builder
  alias ElPaso.Context.Builder.BuiltPrompt

  describe "build/3" do
    test "construye un prompt" do
      context_spec = %{
        model_id: "gpt-4",
        usable_tokens: 4096,
        supports_system_prompt: true
      }

      assert {:ok, %BuiltPrompt{} = prompt} = Builder.build("session-id", "Hola", context_spec)
      assert prompt.session_id == "session-id"
      assert prompt.model_id == "gpt-4"
      assert is_list(prompt.messages)
      assert is_integer(prompt.token_estimate)
    end
  end

  describe "estimate_budget/2" do
    test "estima presupuesto válido" do
      context_spec = %{usable_tokens: 4096}
      prefix_block = %{token_estimate: 100}
      assert {:ok, budget} = Builder.estimate_budget(context_spec, prefix_block)
      assert budget.prefix == 100
    end

    test "falla si el presupuesto es insuficiente" do
      context_spec = %{usable_tokens: 50}
      prefix_block = %{token_estimate: 100}

      assert {:error, :insufficient_token_budget} =
               Builder.estimate_budget(context_spec, prefix_block)
    end
  end
end
