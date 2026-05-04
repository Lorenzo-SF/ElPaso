defmodule ElPaso.Domain.RouterTest do
  use ElPaso.DataCase
  alias ElPaso.Domain.Router
  alias ElPaso.Repo
  alias ElPaso.Models.{Model, Engine}

  setup do
    {:ok, engine} = Repo.insert(%Engine{
      name: "test-engine",
      adapter: "openai",
      base_url: "http://localhost:9999/v1",
      active: true
    })

    {:ok, model1} = Repo.insert(%Model{
      name: "coder-model",
      engine_id: engine.id,
      url: "http://localhost:9999/v1",
      active: true,
      task_affinity: %{code: 0.9, reasoning: 0.5, summarization: 0.3, unknown: 0.5},
      complexity_ceiling: 1.0
    })

    {:ok, model2} = Repo.insert(%Model{
      name: "fast-model",
      engine_id: engine.id,
      url: "http://localhost:9999/v1",
      active: true,
      task_affinity: %{code: 0.3, reasoning: 0.4, summarization: 0.9, unknown: 0.5},
      complexity_ceiling: 0.7
    })

    %{engine: engine, models: [model1, model2]}
  end

  describe "select_model/2" do
    test "selecciona el modelo con mayor affinity para tareas de código", %{} do
      messages = [%{"role" => "user", "content" => "Write a Python function to implement quicksort algorithm"}]
      assert {:ok, %{model_name: "coder-model"}} = Router.select_model(messages, %{})
    end

    test "selecciona modelo para summarization", %{} do
      messages = [%{"role" => "user", "content" => "Summarize this document"}]
      assert {:ok, %{model_name: "fast-model"}} = Router.select_model(messages, %{})
    end

    test "retorna error si no hay modelos activos" do
      Repo.update_all(Model, set: [active: false])
      messages = [%{"role" => "user", "content" => "Hello"}]
      assert {:error, :no_active_model} = Router.select_model(messages, %{})
    end

    test "incluye task_type y score en la decisión" do
      messages = [%{"role" => "user", "content" => "Write code to sort an array"}]
      {:ok, decision} = Router.select_model(messages, %{})
      assert decision.task_type in [:code, :unknown]
      assert is_number(decision.score)
    end
  end

  describe "get_model_state/1" do
    test "devuelve estado para modelo existente" do
      {:ok, state} = Router.get_model_state("coder-model")
      assert state.name == "coder-model"
      assert state.status in ["active", "inactive"]
    end

    test "error para modelo inexistente" do
      assert {:error, :model_not_found} = Router.get_model_state("nonexistent")
    end
  end
end
