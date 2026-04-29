defmodule ElPaso.Domain.ProfileManagerTest do
  @moduledoc """
  Tests para ElPaso.Domain.ProfileManager.
  """

  use ElPaso.DataCase, async: true

  alias ElPaso.Domain.ProfileManager
  alias ElPaso.Models.Profile

  describe "create_profile/1" do
    test "crea un profile válido" do
      assert {:ok, %Profile{} = p} = ProfileManager.create_profile(%{name: "p1"})
      assert p.name == "p1"
    end
  end

  describe "list_profiles/0" do
    test "lista profiles" do
      assert ProfileManager.list_profiles() == []
      {:ok, _} = ProfileManager.create_profile(%{name: "p2"})
      assert length(ProfileManager.list_profiles()) == 1
    end
  end

  describe "get_profile/1" do
    test "obtiene por nombre" do
      {:ok, p} = ProfileManager.create_profile(%{name: "p3"})
      assert ProfileManager.get_profile("p3").id == p.id
    end

    test "devuelve nil si no existe" do
      assert ProfileManager.get_profile("none") == nil
    end
  end

  describe "delete_profile/1" do
    test "elimina un profile" do
      {:ok, _} = ProfileManager.create_profile(%{name: "p4"})
      assert {:ok, %Profile{}} = ProfileManager.delete_profile("p4")
      assert ProfileManager.get_profile("p4") == nil
    end

    test "falla si no existe" do
      assert {:error, "Profile no encontrado"} = ProfileManager.delete_profile("none")
    end
  end
end