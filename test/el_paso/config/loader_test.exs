defmodule ElPaso.Config.LoaderTest do
  @moduledoc """
  Tests para ElPaso.Config.Loader.
  """

  use ExUnit.Case, async: false

  alias ElPaso.Config.Loader

  setup do
    Loader.init_affinity_table()
    :ok
  end

  describe "get/0" do
    test "devuelve un mapa con configuración" do
      config = Loader.get()
      assert is_map(config)
      assert Map.has_key?(config, :inference)
      assert Map.has_key?(config, :auth)
      assert Map.has_key?(config, :cluster)
      assert Map.has_key?(config, :routing)
      assert Map.has_key?(config, :cost_management)
      assert Map.has_key?(config, :database)
    end
  end

  describe "config_get_in/3" do
    test "obtiene valor anidado" do
      assert Loader.config_get_in(%{a: %{b: 1}}, [:a, :b]) == 1
    end

    test "devuelve default si no existe" do
      assert Loader.config_get_in(%{}, [:a, :b], :default) == :default
    end
  end

  describe "get_affinity/2" do
    test "devuelve un float" do
      assert is_float(Loader.get_affinity("model-1", "code"))
    end
  end

  describe "update_affinity/3" do
    test "devuelve :ok" do
      assert :ok = Loader.update_affinity("model-1", "code", 0.8)
    end
  end

  describe "load_config_file/0" do
    test "devuelve un mapa" do
      assert is_map(Loader.load_config_file())
    end
  end

  describe "save_config_file/1" do
    test "guarda configuración" do
      assert :ok = Loader.save_config_file(%{"section" => %{"key" => "value"}})
    end
  end
end
