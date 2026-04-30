defmodule ElPaso.Plugin.Loader do
  @moduledoc """
  Sistema de carga de plugins para engines externos.

  Permite cargar engines dinámicamente desde archivos .ex en disco.
  """

  alias ElPaso.CLI.Output
  alias ElPaso.Engine.Registry

  @doc """
  Carga todos los plugins configurados.
  """
  def load_all(plugins_config) do
    engines = Map.get(plugins_config, :engines, []) || []

    Enum.each(engines, fn plugin ->
      load_engine_plugin(plugin)
    end)
  end

  @doc """
  Carga un plugin de engine específico.
  """
  def load_engine_plugin(%{"path" => path, "module" => module_name}) do
    resolved_path = Path.expand(path)

    unless File.exists?(resolved_path) do
      Output.warning("Plugin no encontrado: #{resolved_path}")
      :skip
    else
      load_and_register_plugin(resolved_path, module_name)
    end
  end

  def load_engine_plugin(_) do
    :skip
  end

  defp load_and_register_plugin(resolved_path, module_name) do
    try do
      # Compilar el archivo
      Code.compile_file(resolved_path)

      # Convertir nombre del módulo a átomo
      module = Module.concat(ElPaso.Engine.Plugin, module_name)

      # Verificar que implementa el behaviour
      unless implements_engine_behaviour?(module) do
        Output.warning("Plugin #{module_name} no implementa ElPaso.Engine behaviour completo")
        :skip
      else
        # Registrar en el registry
        engine_name = module.name()
        Registry.register(engine_name, module)
        Output.success("Plugin de engine cargado: #{module_name} (#{engine_name})")
        {:ok, engine_name}
      end
    rescue
      e ->
        Output.error("Error cargando plugin #{module_name}: #{Exception.message(e)}")
        :skip
    end
  end

  defp implements_engine_behaviour?(module) do
    # Verificar que el módulo implementa las callbacks requeridas
    functions = [
      {:name, 0},
      {:type, 0},
      {:infer, 3},
      {:stream, 4},
      {:prepare_prefix, 2},
      {:health_check, 1},
      {:format_messages, 2}
    ]

    Enum.all?(functions, fn {fun, arity} ->
      function_exported?(module, fun, arity)
    end)
  end

  @doc """
  Descarga un plugin (lo desregistra).
  """
  def unload_engine_plugin(engine_name) do
    Registry.unregister(engine_name)
    Output.error("Plugin de engine descargado: #{engine_name}")
    :ok
  end

  @doc """
  Lista los plugins disponibles en un directorio.
  """
  def list_available_plugins(plugins_dir \\ "plugins") do
    path = Path.expand(plugins_dir)

    unless File.exists?(path) do
      []
    else
      path
      |> Path.join("*.ex")
      |> Path.wildcard()
      |> Enum.map(fn file ->
        filename = Path.basename(file, ".ex")
        %{path: file, module: filename}
      end)
    end
  end
end
