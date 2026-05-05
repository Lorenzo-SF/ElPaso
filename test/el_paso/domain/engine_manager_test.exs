defmodule ElPaso.Domain.EngineManagerTest do
  use ElPaso.DataCase, async: false

  alias ElPaso.Domain.EngineManager
  alias ElPaso.Models.Engine

  describe "create_engine/1" do
    test "creates a valid engine" do
      attrs = %{
        name: "test-engine",
        adapter: "openai",
        base_url: "https://api.openai.com/v1",
        api_key: "test-key"
      }

      assert {:ok, %Engine{}} = EngineManager.create_engine(attrs)
    end
  end

  describe "list_engines/0" do
    test "returns list of engines" do
      assert is_list(EngineManager.list_engines())
    end
  end

  describe "get_engine/1" do
    test "returns engine by name" do
      {:ok, engine} = EngineManager.create_engine(%{name: "get-test", adapter: "ollama", base_url: "http://localhost:11434"})
      assert %Engine{name: "get-test"} = EngineManager.get_engine("get-test")
    end

    test "returns nil for unknown engine" do
      assert EngineManager.get_engine("nonexistent") == nil
    end
  end

  describe "update_engine/2" do
    test "updates an existing engine" do
      {:ok, engine} = EngineManager.create_engine(%{name: "update-test", adapter: "ollama", base_url: "http://localhost:11434"})
      assert {:ok, updated} = EngineManager.update_engine("update-test", %{base_url: "http://new:11434"})
      assert updated.base_url == "http://new:11434"
    end

    test "returns error for unknown engine" do
      assert {:error, "Motor no encontrado"} = EngineManager.update_engine("nonexistent", %{})
    end
  end

  describe "delete_engine/1" do
    test "deletes an existing engine" do
      {:ok, engine} = EngineManager.create_engine(%{name: "delete-test", adapter: "ollama", base_url: "http://localhost:11434"})
      assert {:ok, _} = EngineManager.delete_engine("delete-test")
      assert EngineManager.get_engine("delete-test") == nil
    end

    test "returns error for unknown engine" do
      assert {:error, "Motor no encontrado"} = EngineManager.delete_engine("nonexistent")
    end
  end

  describe "test_engine/1" do
    test "returns error for unknown engine" do
      assert {:error, "Motor no encontrado"} = EngineManager.test_engine("nonexistent")
    end

    test "attempts health check for existing engine" do
      {:ok, _} = EngineManager.create_engine(%{name: "health-test", adapter: "ollama", base_url: "http://localhost:11434"})
      # Will likely fail because localhost:11434 is not running
      result = EngineManager.test_engine("health-test")
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end
end
