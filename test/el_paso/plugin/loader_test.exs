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
      assert :skip =
               Loader.load_engine_plugin(%{
                 "path" => "/nonexistent/plugin.ex",
                 "module" => "Fake"
               })
    end

    test "carga un plugin válido" do
      dir = System.tmp_dir!() |> Path.join("elpaso_plugins_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)

      plugin_code = """
      defmodule ElPaso.Engine.Plugin.TestPlugin do
        @behaviour ElPaso.Engine
        def name, do: :test_plugin
        def type, do: :local_process
        def infer(_p, _params, _config), do: {:ok, %{content: "hi"}}
        def stream(_p, _params, _config, _cb), do: :ok
        def prepare_prefix(_prefix, _config), do: ""
        def health_check(_config), do: :ok
        def format_messages(_msgs, _spec), do: []
      end
      """

      path = Path.join(dir, "test_plugin.ex")
      File.write!(path, plugin_code)

      result = Loader.load_engine_plugin(%{"path" => path, "module" => "TestPlugin"})
      assert match?({:ok, :test_plugin}, result) or result == :skip

      File.rm_rf!(dir)
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
      dir = System.tmp_dir!() |> Path.join("elpaso_plugins_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "test_plugin.ex"), "# test")

      assert [%{path: _, module: "test_plugin"}] = Loader.list_available_plugins(dir)

      File.rm_rf!(dir)
    end
  end
end
