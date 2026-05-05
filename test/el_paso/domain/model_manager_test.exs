defmodule ElPaso.Domain.ModelManagerTest do
  use ElPaso.DataCase, async: false

  alias ElPaso.Domain.ModelManager
  alias ElPaso.Models.Model

  setup do
    start_supervised!(ModelManager)
    start_supervised!({Task.Supervisor, name: ElPaso.TaskSupervisor})
    start_supervised!({Registry, keys: :unique, name: Zaguan.Engine.CircuitBreaker.Registry})
    :ok
  end

  describe "DB operations" do
    test "create_model/1 creates a model" do
      attrs = %{
        name: "test-model",
        config: %{},
        active: true,
        max_tokens: 4096,
        temperature: 0.7,
        top_p: 1.0
      }

      assert {:ok, %Model{}} = ModelManager.create_model(attrs)
    end

    test "list_models/0 returns models" do
      assert is_list(ModelManager.list_models())
    end

    test "get_model/1 returns model by name" do
      {:ok, _} = ModelManager.create_model(%{name: "get-model", config: %{}, active: true})
      assert %Model{name: "get-model"} = ModelManager.get_model("get-model")
    end

    test "get_model/1 returns nil for unknown" do
      assert ModelManager.get_model("nonexistent") == nil
    end

    test "update_model/2 updates a model" do
      {:ok, _} = ModelManager.create_model(%{name: "update-model", config: %{}, active: true})
      assert {:ok, updated} = ModelManager.update_model("update-model", %{temperature: 0.5})
      assert updated.temperature == 0.5
    end

    test "update_model/2 returns error for unknown" do
      assert {:error, "Modelo no encontrado"} = ModelManager.update_model("nonexistent", %{})
    end

    test "delete_model/1 deletes a model" do
      {:ok, _} = ModelManager.create_model(%{name: "delete-model", config: %{}, active: true})
      assert {:ok, _} = ModelManager.delete_model("delete-model")
      assert ModelManager.get_model("delete-model") == nil
    end

    test "delete_model/1 returns error for unknown" do
      assert {:error, "Modelo no encontrado"} = ModelManager.delete_model("nonexistent")
    end

    test "start_model/1 activates a model" do
      {:ok, _} = ModelManager.create_model(%{name: "start-model", config: %{}, active: false})
      assert {:ok, started} = ModelManager.start_model("start-model")
      assert started.active == true
    end

    test "stop_model/1 deactivates a model" do
      {:ok, _} = ModelManager.create_model(%{name: "stop-model", config: %{}, active: true})
      assert {:ok, stopped} = ModelManager.stop_model("stop-model")
      assert stopped.active == false
    end

    test "load_models/0 loads all models" do
      assert is_list(ModelManager.load_models())
    end

    test "models/0 returns all models" do
      assert is_list(ModelManager.models())
    end
  end

  describe "GenServer operations" do
    test "all_states/0 returns model states" do
      assert is_list(ModelManager.all_states())
    end

    test "reload_models/0 reloads from DB" do
      assert {:ok, _count} = ModelManager.reload_models()
    end

    test "infer/2 returns error for unknown model" do
      assert {:error, :model_not_found} = ModelManager.infer("nonexistent-model", %{})
    end

    test "infer/2 with valid model and no engine" do
      {:ok, _} = ModelManager.create_model(%{name: "infer-no-engine", config: %{}, active: true})
      # Need to reload so GenServer knows about it
      ModelManager.reload_models()
      result = ModelManager.infer("infer-no-engine", %{messages: []})
      # CircuitBreaker wraps the result in {:ok, result}, so we get {:ok, {:error, _}}
      assert match?({:ok, {:error, _}}, result)
    end
  end

  describe "init" do
    test "init loads models safely" do
      assert {:ok, state} = ModelManager.init([])
      assert is_list(state.models)
      assert is_map(state.engine_states)
    end
  end
end
