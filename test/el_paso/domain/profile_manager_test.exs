defmodule ElPaso.Domain.ProfileManagerTest do
  use ElPaso.DataCase, async: false

  alias ElPaso.Domain.ProfileManager
  alias ElPaso.Models.Profile

  describe "create_profile/1" do
    test "creates a profile" do
      attrs = %{
        name: "test-profile",
        config: %{},
        active: true,
        description: "Test"
      }

      assert {:ok, %Profile{}} = ProfileManager.create_profile(attrs)
    end

    test "returns error for invalid attrs" do
      assert {:error, %Ecto.Changeset{}} = ProfileManager.create_profile(%{})
    end
  end

  describe "list_profiles/0" do
    test "returns list of profiles" do
      assert is_list(ProfileManager.list_profiles())
    end
  end

  describe "get_profile/1" do
    test "returns profile by name" do
      {:ok, _} = ProfileManager.create_profile(%{name: "get-profile", description: "Test"})
      assert %Profile{name: "get-profile"} = ProfileManager.get_profile("get-profile")
    end

    test "returns nil for unknown" do
      assert ProfileManager.get_profile("nonexistent") == nil
    end
  end

  describe "delete_profile/1" do
    test "deletes an existing profile" do
      {:ok, _} = ProfileManager.create_profile(%{name: "delete-profile", description: "Test"})
      assert {:ok, _} = ProfileManager.delete_profile("delete-profile")
      assert ProfileManager.get_profile("delete-profile") == nil
    end

    test "returns error for unknown profile" do
      assert {:error, "Profile no encontrado"} = ProfileManager.delete_profile("nonexistent")
    end
  end
end
