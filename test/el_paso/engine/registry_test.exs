defmodule ElPaso.Engine.RegistryTest do
  @moduledoc """
  Tests para ElPaso.Engine.Registry.
  """

  use ExUnit.Case, async: false

  alias ElPaso.Engine.Registry

  setup do
    start_supervised!({Registry, []})
    :ok
  end

  describe "register/2" do
    test "registra un engine" do
      assert :ok = Registry.register(:test_engine, MyEngine)
      assert {:ok, MyEngine} = Registry.get(:test_engine)
    end
  end

  describe "get/1" do
    test "devuelve error si no existe" do
      assert {:error, :not_found} = Registry.get(:nonexistent)
    end
  end

  describe "list_all/0" do
    test "lista engines registrados" do
      Registry.register(:e1, Mod1)
      Registry.register(:e2, Mod2)
      assert length(Registry.list_all()) == 2
    end
  end

  describe "unregister/1" do
    test "desregistra un engine" do
      Registry.register(:temp, TempMod)
      assert :ok = Registry.unregister(:temp)
      assert {:error, :not_found} = Registry.get(:temp)
    end
  end
end
