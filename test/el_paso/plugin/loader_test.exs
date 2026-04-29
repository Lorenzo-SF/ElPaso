defmodule ElPaso.Plugin.LoaderTest do
  @moduledoc """
  Tests para ElPaso.Plugin.Loader.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Plugin.Loader

  describe "load_engine_plugin/1" do
    test "skip si falta path o module" do
      assert :skip = Loader.load_engine_plugin(%{})
      assert :skip = Loader.load_engine_plugin(%{"path" => "/tmp/fake.ex"})
    end

    test "skip si el archivo no existe" do
      assert :skip = Loader.load_engine_plugin(%{"path" => "/nonexistent/plugin.ex", "module" => "Fake"})
    end
  end

  describe "unload_engine_plugin/1" do
    test "devuelve :ok" do
      assert :ok = Loader.unload_engine_plugin(:fake_engine)
    end
  end

  describe "list_available_plugins/1" do
    test "devuelve lista vacía si el directorio no existe" do
      assert Loader.list_available_plugins("/nonexistent_plugins") == []
    end

    test "lista archivos .ex en el directorio" do
      # Crear un directorio temporal con un archivo .ex
      dir = System.tmp_dir!() |> Path.join("elpaso_plugins_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "test_plugin.ex"), "# test")

      assert [%{path: _, module: "test_plugin"}] = Loader.list_available_plugins(dir)
    after
      # Limpieza aproximada
      File.rm_rf(System.tmp_dir!() |> Path.join("elpaso_plugins_*"))
    end
  end
end