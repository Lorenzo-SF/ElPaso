defmodule ElPaso.Domain.PersonalityManagerTest do
  use ElPaso.DataCase, async: false

  alias ElPaso.Domain.PersonalityManager
  alias ElPaso.Models.Personality

  describe "create_personality/1" do
    test "creates a personality" do
      attrs = %{
        name: "developer",
        description: "Coding assistant",
        system_prompt: "You are a helpful coding assistant.",
        active: true
      }

      assert {:ok, %Personality{}} = PersonalityManager.create_personality(attrs)
    end

    test "returns error for invalid attrs" do
      assert {:error, %Ecto.Changeset{}} = PersonalityManager.create_personality(%{})
    end
  end

  describe "list_personalities/0" do
    test "returns list of personalities" do
      assert is_list(PersonalityManager.list_personalities())
    end
  end

  describe "get_personality/1" do
    test "returns personality by name" do
      {:ok, p} = PersonalityManager.create_personality(%{
        name: "get-test",
        system_prompt: "Test prompt"
      })

      assert %Personality{name: "get-test"} = PersonalityManager.get_personality("get-test")
    end

    test "returns nil for unknown" do
      assert PersonalityManager.get_personality("nonexistent") == nil
    end
  end

  describe "update_personality/2" do
    test "updates an existing personality" do
      {:ok, _} = PersonalityManager.create_personality(%{
        name: "update-test",
        system_prompt: "Original"
      })

      assert {:ok, updated} = PersonalityManager.update_personality("update-test", %{system_prompt: "Updated"})
      assert updated.system_prompt == "Updated"
    end

    test "returns error for unknown personality" do
      assert {:error, "Personalidad no encontrada"} = PersonalityManager.update_personality("nonexistent", %{})
    end
  end

  describe "delete_personality/1" do
    test "deletes an existing personality" do
      {:ok, _} = PersonalityManager.create_personality(%{
        name: "delete-test",
        system_prompt: "To delete"
      })

      assert {:ok, _} = PersonalityManager.delete_personality("delete-test")
      assert PersonalityManager.get_personality("delete-test") == nil
    end

    test "returns error for unknown personality" do
      assert {:error, "Personalidad no encontrada"} = PersonalityManager.delete_personality("nonexistent")
    end
  end
end
