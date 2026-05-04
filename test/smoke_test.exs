defmodule ElPaso.SmokeTest do
  use ExUnit.Case, async: false
  import Ecto.Query

  alias ElPaso.Repo
  alias ElPaso.Models.{Engine, Model, Personality}
  alias ElPaso.Domain.{EngineManager, ModelManager, PersonalityManager}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "EngineManager" do
    test "crea y lista engines" do
      {:ok, engine} = EngineManager.create_engine(%{
        name: "test-engine-smoke",
        adapter: "openai",
        base_url: "http://localhost:9999/v1"
      })

      engines = EngineManager.list_engines()
      assert length(engines) > 0
      assert Enum.any?(engines, &(&1.name == "test-engine-smoke"))
    end
  end

  describe "ModelManager" do
    setup do
      {:ok, engine} = EngineManager.create_engine(%{
        name: "test-engine-model",
        adapter: "openai",
        base_url: "http://localhost:9999/v1"
      })
      %{engine: engine}
    end

    test "crea y lista modelos", %{engine: engine} do
      {:ok, model} = ModelManager.create_model(%{
        name: "test-model-smoke",
        engine_id: engine.id,
        url: "http://localhost:9999/v1"
      })

      models = ModelManager.list_models()
      assert length(models) > 0
      assert Enum.any?(models, &(&1.name == "test-model-smoke"))
    end

    test "start_model y stop_model cambian active", %{engine: engine} do
      {:ok, model} = ModelManager.create_model(%{
        name: "test-model-toggle",
        engine_id: engine.id,
        url: "http://localhost:9999/v1"
      })

      {:ok, stopped} = ModelManager.stop_model("test-model-toggle")
      refute stopped.active

      {:ok, started} = ModelManager.start_model("test-model-toggle")
      assert started.active
    end

    test "get_model encuentra por nombre", %{engine: engine} do
      {:ok, _} = ModelManager.create_model(%{
        name: "test-model-get",
        engine_id: engine.id,
        url: "http://localhost:9999/v1"
      })

      found = ModelManager.get_model("test-model-get")
      assert found != nil
      assert found.name == "test-model-get"
    end
  end
end
