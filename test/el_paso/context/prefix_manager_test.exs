defmodule ElPaso.Context.PrefixManagerTest do
  @moduledoc """
  Tests para ElPaso.Context.PrefixManager.
  """

  use ExUnit.Case, async: false

  alias ElPaso.Context.PrefixManager

  setup do
    start_supervised!({PrefixManager, []})
    :ok
  end

  describe "build/2" do
    test "construye un bloque canónico" do
      assert {:ok, block} = PrefixManager.build("sess-1", %{system_prompt: "Eres útil."})
      assert block.session_id == "sess-1"
      assert block.content =~ "Eres útil."
      assert is_binary(block.hash)
      assert block.token_estimate > 0
    end
  end

  describe "get/1" do
    test "obtiene un bloque existente" do
      {:ok, _} = PrefixManager.build("sess-2", %{system_prompt: "Hola."})
      assert {:ok, block} = PrefixManager.get("sess-2")
      assert block.session_id == "sess-2"
    end

    test "devuelve error si no existe" do
      assert {:error, :not_found} = PrefixManager.get("sess-none")
    end
  end

  describe "invalidate/1" do
    test "elimina un bloque" do
      {:ok, _} = PrefixManager.build("sess-3", %{system_prompt: "Adiós."})
      assert :ok = PrefixManager.invalidate("sess-3")
      assert {:error, :not_found} = PrefixManager.get("sess-3")
    end
  end

  describe "hash/1" do
    test "devuelve el hash de un bloque" do
      {:ok, block} = PrefixManager.build("sess-4", %{system_prompt: "Test."})
      assert {:ok, hash} = PrefixManager.hash("sess-4")
      assert hash == block.hash
    end

    test "devuelve error si no existe" do
      assert {:error, :not_found} = PrefixManager.hash("sess-none")
    end
  end
end
