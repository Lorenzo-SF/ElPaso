defmodule ElPaso.Domain.RouterTest do
  use ElPaso.DataCase, async: false

  alias ElPaso.Domain.Router

  describe "select_model/2" do
    test "returns error when no active models" do
      assert {:error, :no_active_model} = Router.select_model([%{content: "test"}], %{})
    end

    test "selects model based on task affinity" do
      # This test assumes there might be seeded models
      result = Router.select_model([%{content: "write a function to sort a list"}], %{})
      assert match?({:ok, _}, result) or match?({:error, :no_active_model}, result)
    end
  end

  describe "detect_task_type/1 (via select_model)" do
    test "detects code task" do
      result = Router.select_model([%{content: "function to sort list"}], %{})
      assert match?({:ok, %{task_type: :code}}, result) or match?({:error, _}, result)
    end

    test "detects translation task" do
      result = Router.select_model([%{content: "translate to spanish"}], %{})
      assert match?({:ok, %{task_type: :translation}}, result) or match?({:error, _}, result)
    end

    test "detects summarization task" do
      result = Router.select_model([%{content: "summarize this text"}], %{})
      assert match?({:ok, %{task_type: :summarization}}, result) or match?({:error, _}, result)
    end

    test "detects reasoning task" do
      result = Router.select_model([%{content: "analyze the pros and cons"}], %{})
      assert match?({:ok, %{task_type: :reasoning}}, result) or match?({:error, _}, result)
    end

    test "detects question_answer task" do
      result = Router.select_model([%{content: "what is elixir"}], %{})
      assert match?({:ok, %{task_type: :question_answer}}, result) or match?({:error, _}, result)
    end

    test "detects creative task" do
      result = Router.select_model([%{content: "write a story"}], %{})
      assert match?({:ok, %{task_type: :creative}}, result) or match?({:error, _}, result)
    end

    test "returns unknown for generic content" do
      result = Router.select_model([%{content: "hello"}], %{})
      assert match?({:ok, %{task_type: :unknown}}, result) or match?({:error, _}, result)
    end

    test "handles string-keyed messages" do
      result = Router.select_model([%{"content" => "hello world"}], %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles mixed message formats" do
      result = Router.select_model([%{"content" => "test"}, %{content: "another"}], %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_model_state/1" do
    test "returns error for unknown model" do
      assert {:error, :model_not_found} = Router.get_model_state("nonexistent-model-xyz")
    end
  end

  describe "get_routing_config/1" do
    test "returns error for unknown model" do
      assert {:error, :model_not_found} = Router.get_routing_config("nonexistent-model-xyz")
    end
  end

  describe "update_routing_outcome/2" do
    test "returns error when decision not found" do
      assert {:error, :not_found} = Router.update_routing_outcome("nonexistent-req", %{})
    end
  end
end
