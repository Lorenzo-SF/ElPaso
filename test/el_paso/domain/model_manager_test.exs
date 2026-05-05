defmodule ElPaso.Domain.ModelManagerTest do
  @moduledoc """
  Tests para ElPaso.Domain.ModelManager.
  """

  use ElPaso.DataCase, async: false

  alias ElPaso.Domain.ModelManager
  alias ElPaso.Models.{Model, Engine}

  setup do
    {:ok, engine} =
      ElPaso.Repo.insert(%Engine{
        name: "mm-engine",
        adapter: "ollama",
        base_url: "http://localhost:11434"
      })

    start_supervised!({ModelManager, []})
    %{engine: engine}
  end

  describe "create_model/1" do
    test "crea un modelo con atributos válidos", %{engine: engine} do
      attrs = %{name: "gpt-4-test", engine_id: engine.id, active: true}
      assert {:ok, %Model{} = model} = ModelManager.create_model(attrs)
      assert model.name == "gpt-4-test"
    end

    test "falla sin campos requeridos" do
      assert {:error, %Ecto.Changeset{}} = ModelManager.create_model(%{})
    end
  end

  describe "list_models/0" do
    test "lista todos los modelos", %{engine: engine} do
      assert ModelManager.list_models() == []
      {:ok, _model} = ModelManager.create_model(%{name: "m1", engine_id: engine.id})
      assert length(ModelManager.list_models()) == 1
    end
  end

  describe "get_model/1" do
    test "obtiene un modelo por nombre", %{engine: engine} do
      {:ok, model} = ModelManager.create_model(%{name: "m2", engine_id: engine.id})
      assert ModelManager.get_model("m2").id == model.id
    end

    test "devuelve nil si no existe" do
      assert ModelManager.get_model("nonexistent") == nil
    end
  end

  describe "delete_model/1" do
    test "elimina un modelo existente", %{engine: engine} do
      {:ok, _model} = ModelManager.create_model(%{name: "m3", engine_id: engine.id})
      assert {:ok, %Model{}} = ModelManager.delete_model("m3")
      assert ModelManager.get_model("m3") == nil
    end

    test "falla si el modelo no existe" do
      assert {:error, "Modelo no encontrado"} = ModelManager.delete_model("nonexistent")
    end
  end

  describe "update_model/2" do
    test "actualiza un modelo existente", %{engine: engine} do
      {:ok, _model} = ModelManager.create_model(%{name: "m4", engine_id: engine.id})
      assert {:ok, %Model{} = updated} = ModelManager.update_model("m4", %{active: false})
      refute updated.active
    end

    test "falla si el modelo no existe" do
      assert {:error, "Modelo no encontrado"} = ModelManager.update_model("nonexistent", %{})
    end
  end

  describe "start_model/1" do
    test "activa un modelo", %{engine: engine} do
      {:ok, model} = ModelManager.create_model(%{name: "m5", engine_id: engine.id, active: false})
      refute model.active
      assert {:ok, %Model{} = updated} = ModelManager.start_model("m5")
      assert updated.active
    end
  end

  describe "stop_model/1" do
    test "desactiva un modelo", %{engine: engine} do
      {:ok, _model} = ModelManager.create_model(%{name: "m6", engine_id: engine.id, active: true})
      assert {:ok, %Model{} = updated} = ModelManager.stop_model("m6")
      refute updated.active
    end
  end

  describe "models/0" do
    test "devuelve todos los modelos", %{engine: engine} do
      assert ModelManager.models() == []
      {:ok, _model} = ModelManager.create_model(%{name: "m7", engine_id: engine.id})
      assert length(ModelManager.models()) == 1
    end
  end

  describe "all_states/0" do
    test "devuelve estados de modelos" do
      assert is_list(ModelManager.all_states())
    end
  end

  describe "infer/2" do
    test "devuelve error si el modelo no existe" do
      assert {:error, :model_not_found} = ModelManager.infer("nonexistent", %{prompt: "hi"})
    end
  end
end
