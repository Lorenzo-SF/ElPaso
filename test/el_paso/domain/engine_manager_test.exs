defmodule ElPaso.Domain.EngineManagerTest do
  @moduledoc """
  Tests para ElPaso.Domain.EngineManager.
  """

  use ElPaso.DataCase, async: true

  alias ElPaso.Domain.EngineManager
  alias ElPaso.Models.Engine

  describe "create_engine/1" do
    test "crea un engine con atributos válidos" do
      attrs = %{name: "test-ollama", adapter: "ollama", base_url: "http://localhost:11434"}
      assert {:ok, %Engine{} = engine} = EngineManager.create_engine(attrs)
      assert engine.name == "test-ollama"
      assert engine.adapter == "ollama"
    end

    test "falla sin campos requeridos" do
      assert {:error, %Ecto.Changeset{}} = EngineManager.create_engine(%{})
    end
  end

  describe "list_engines/0" do
    test "lista todos los engines" do
      assert EngineManager.list_engines() == []

      {:ok, _engine} =
        EngineManager.create_engine(%{
          name: "e1",
          adapter: "ollama",
          base_url: "http://localhost:11434"
        })

      assert length(EngineManager.list_engines()) == 1
    end
  end

  describe "get_engine/1" do
    test "obtiene un engine por nombre" do
      {:ok, engine} =
        EngineManager.create_engine(%{
          name: "e2",
          adapter: "openai",
          base_url: "http://api.openai.com"
        })

      assert EngineManager.get_engine("e2").id == engine.id
    end

    test "devuelve nil si no existe" do
      assert EngineManager.get_engine("nonexistent") == nil
    end
  end

  describe "delete_engine/1" do
    test "elimina un engine existente" do
      {:ok, _engine} =
        EngineManager.create_engine(%{
          name: "e3",
          adapter: "ollama",
          base_url: "http://localhost:11434"
        })

      assert {:ok, %Engine{}} = EngineManager.delete_engine("e3")
      assert EngineManager.get_engine("e3") == nil
    end

    test "falla si el engine no existe" do
      assert {:error, "Motor no encontrado"} = EngineManager.delete_engine("nonexistent")
    end
  end

  describe "update_engine/2" do
    test "actualiza un engine existente" do
      {:ok, _engine} =
        EngineManager.create_engine(%{
          name: "e4",
          adapter: "ollama",
          base_url: "http://localhost:11434"
        })

      assert {:ok, %Engine{} = updated} =
               EngineManager.update_engine("e4", %{base_url: "http://new-url.com"})

      assert updated.base_url == "http://new-url.com"
    end

    test "falla si el engine no existe" do
      assert {:error, "Motor no encontrado"} =
               EngineManager.update_engine("nonexistent", %{base_url: "x"})
    end
  end

  describe "test_engine/1" do
    test "verifica conectividad de un engine existente" do
      {:ok, _engine} =
        EngineManager.create_engine(%{
          name: "e5",
          adapter: "ollama",
          base_url: "http://localhost:11434"
        })

      assert :ok = EngineManager.test_engine("e5")
    end

    test "falla si el engine no existe" do
      assert {:error, "Motor no encontrado"} = EngineManager.test_engine("nonexistent")
    end
  end
end
