defmodule ElPaso.Domain.PersonalityManagerTest do
  @moduledoc """
  Tests para ElPaso.Domain.PersonalityManager.
  """

  use ElPaso.DataCase, async: true

  alias ElPaso.Domain.PersonalityManager
  alias ElPaso.Models.Personality

  describe "create_personality/1" do
    test "crea una personalidad válida" do
      assert {:ok, %Personality{} = per} = PersonalityManager.create_personality(%{name: "per1"})
      assert per.name == "per1"
    end
  end

  describe "list_personalities/0" do
    test "lista personalidades" do
      assert PersonalityManager.list_personalities() == []
      {:ok, _} = PersonalityManager.create_personality(%{name: "per2"})
      assert length(PersonalityManager.list_personalities()) == 1
    end
  end

  describe "get_personality/1" do
    test "obtiene por nombre" do
      {:ok, per} = PersonalityManager.create_personality(%{name: "per3"})
      assert PersonalityManager.get_personality("per3").id == per.id
    end

    test "devuelve nil si no existe" do
      assert PersonalityManager.get_personality("none") == nil
    end
  end

  describe "delete_personality/1" do
    test "elimina una personalidad" do
      {:ok, _} = PersonalityManager.create_personality(%{name: "per4"})
      assert {:ok, %Personality{}} = PersonalityManager.delete_personality("per4")
      assert PersonalityManager.get_personality("per4") == nil
    end

    test "falla si no existe" do
      assert {:error, "Personalidad no encontrada"} = PersonalityManager.delete_personality("none")
    end
  end

  describe "update_personality/2" do
    test "actualiza una personalidad" do
      {:ok, _} = PersonalityManager.create_personality(%{name: "per5"})
      assert {:ok, %Personality{} = updated} = PersonalityManager.update_personality("per5", %{description: "desc"})
      assert updated.description == "desc"
    end

    test "falla si no existe" do
      assert {:error, "Personalidad no encontrada"} = PersonalityManager.update_personality("none", %{})
    end
  end
end