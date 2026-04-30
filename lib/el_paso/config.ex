defmodule ElPaso.Config do
  @moduledoc """
  Módulo para gestión de configuración del sistema.
  ...
  """

  alias ElPaso.Config.Loader

  defmodule Loader do
    @moduledoc """
    Loader de configuración del sistema.
    ...
    """

    @config_file Path.join([System.user_home!(), ".config", "elpaso", "elpaso.conf"])

    # Helper function to get nested values from maps (avoiding conflict with Kernel.get_in)
    def config_get_in(map, keys, default \\ nil) do
      case Enum.reduce(keys, map, fn key, acc ->
             case acc do
               %{^key => value} -> value
               _ -> nil
             end
           end) do
        nil -> default
        value -> value
      end
    end

    # Helper function to create a reference-like structure
    def ref(value) do
      {value}
    end

    @doc """
    Devuelve la configuración actual del sistema.
    En modo de desarrollo o test, devuelve valores por defecto si no hay configuración válida.
    En producción, falla si no hay configuración mínima requerida.
    """
    def get do
      # Cargar desde archivo de configuración (prioridad baja)
      file_config = load_config_file()

      # Merge con variables de entorno (prioridad alta)
      env_inference_url = System.get_env("ELPASO_INFERENCE_URL")
      env_inference_api_key = System.get_env("ELPASO_INFERENCE_API_KEY")
      _env_port = System.get_env("ELPASO_PORT")
      env_auth_enabled = System.get_env("ELPASO_AUTH_ENABLED")
      env_allow_anonymous = System.get_env("ELPASO_ALLOW_ANONYMOUS")
      env_cluster_enabled = System.get_env("ELPASO_CLUSTER_ENABLED")
      env_cluster_discovery = System.get_env("ELPASO_CLUSTER_DISCOVERY")
      env_node_name = System.get_env("ELPASO_NODE_NAME")
      env_model_routing = System.get_env("ELPASO_MODEL_ROUTING")
      env_cost_enabled = System.get_env("ELPASO_COST_ENABLED")
      env_daily_limit = System.get_env("ELPASO_DAILY_LIMIT")
      env_alert_pct = System.get_env("ELPASO_ALERT_PCT")
      env_db_host = System.get_env("DB_HOST")
      env_db_user = System.get_env("DB_USER")
      env_db_password = System.get_env("DB_PASSWORD")
      env_db_name = System.get_env("DB_NAME")
      env_db_port = System.get_env("DB_PORT")

      # Detectar si estamos en modo producción
      is_prod = Application.get_env(:elpaso, :env) == :prod

      if is_prod and (!env_inference_url or !env_inference_api_key) do
        raise """
        ⚠️ CONFIGURACIÓN REQUERIDA

        El sistema requiere las siguientes variables de entorno:

          export ELPASO_INFERENCE_URL="https://tu-servidor-api.com/v1"
          export ELPASO_INFERENCE_API_KEY="sk-tu-api-key"

        Ejemplo para OpenAI:
          export ELPASO_INFERENCE_URL="https://api.openai.com/v1"
          export ELPASO_INFERENCE_API_KEY="sk-tu-api-key"

        Ejemplo para Ollama local:
          export ELPASO_INFERENCE_URL="http://localhost:11434/v1"
          export ELPASO_INFERENCE_API_KEY="no-api-key-required"

        Para más opciones: elpaso config --wizard
        """
      end

      # En modo no producción, usar valores por defecto para permitir arranque
      inference_url =
        env_inference_url || config_get_in(file_config, [:inference, "url"]) ||
          "http://localhost:8081/v1"

      inference_api_key =
        env_inference_api_key || config_get_in(file_config, [:inference, "api_key"]) ||
          "sk-local-test"

      %{
        inference: %{
          url: inference_url,
          api_key: inference_api_key
        },
        auth: %{
          enabled:
            parse_bool(env_auth_enabled, config_get_in(file_config, [:auth, "enabled"], false)),
          allow_anonymous:
            parse_bool(
              env_allow_anonymous,
              config_get_in(file_config, [:auth, "allow_anonymous"], true)
            )
        },
        cluster: %{
          enabled:
            parse_bool(
              env_cluster_enabled,
              config_get_in(file_config, [:cluster, "enabled"], false)
            ),
          node_name: env_node_name || config_get_in(file_config, [:cluster, "node_name"]),
          role: config_get_in(file_config, [:cluster, "role"]) || :both,
          discovery:
            env_cluster_discovery || config_get_in(file_config, [:cluster, "discovery"]) ||
              "static"
        },
        routing: %{
          auto_tune:
            parse_bool(
              env_model_routing,
              config_get_in(file_config, [:routing, "auto_tune"], false)
            ),
          auto_tune_min_confidence:
            parse_float(
              env_model_routing,
              config_get_in(file_config, [:routing, "auto_tune_min_confidence"], 0.85)
            ),
          auto_tune_min_decisions:
            parse_int(
              env_model_routing,
              config_get_in(file_config, [:routing, "auto_tune_min_decisions"], 50)
            ),
          auto_tune_check_interval_hours:
            parse_float(
              env_model_routing,
              config_get_in(file_config, [:routing, "auto_tune_check_interval_hours"], 24)
            )
        },
        cost_management: %{
          enabled:
            parse_bool(
              env_cost_enabled,
              config_get_in(file_config, [:cost_management, "enabled"], false)
            ),
          daily_usd:
            parse_float(
              env_daily_limit,
              config_get_in(file_config, [:cost_management, "daily_usd"], 100.0)
            ),
          alert_at_pct:
            parse_float(
              env_alert_pct,
              config_get_in(file_config, [:cost_management, "alert_at_pct"], 80)
            )
        },
        database: %{
          host: env_db_host || config_get_in(file_config, [:database, "host"]) || "localhost",
          user: env_db_user || config_get_in(file_config, [:database, "user"]) || "postgres",
          password:
            env_db_password || config_get_in(file_config, [:database, "password"]) || "postgres",
          name: env_db_name || config_get_in(file_config, [:database, "name"]) || "elpaso_prod",
          port: parse_int(env_db_port, config_get_in(file_config, [:database, "port"], 5432))
        }
      }
    end

    @doc """
    Obtiene la affinity para una combinación (model_id, task_type).

    Busca en ETS :affinity_table, fallback a archivo de config, luego 0.5.
    """
    def get_affinity(model_id, task_type) do
      key = {model_id, task_type}

      case :ets.lookup(:affinity_table, key) do
        [{^key, affinity}] ->
          affinity

        [] ->
          # Fallback: buscar en archivo de configuración
          config = load_config_file()

          task_str = if is_atom(task_type), do: Atom.to_string(task_type), else: task_type
          get_in(config, ["routing", "affinities", model_id, task_str]) || 0.5
      end
    end

    @doc """
    Actualiza la affinity para una combinación y persiste en ETS.

    Para persistencia durable, los cambios se guardan en el archivo de config.
    """
    def update_affinity(model_id, task_type, affinity) do
      # Guardar en ETS (en memoria, rápido)
      :ets.insert(:affinity_table, {{model_id, task_type}, affinity})

      # Persistir en archivo de configuración
      config = load_config_file()

      task_str = if is_atom(task_type), do: Atom.to_string(task_type), else: task_type

      # Ensure nested structure exists
      routing = Map.get(config, :routing, %{})
      affinities = Map.get(routing, "affinities", %{})
      model_affinities = Map.get(affinities, model_id, %{})
      updated_model_affinities = Map.put(model_affinities, task_str, affinity)
      updated_affinities = Map.put(affinities, model_id, updated_model_affinities)
      updated_routing = Map.put(routing, "affinities", updated_affinities)
      updated_config = Map.put(config, :routing, updated_routing)

      save_config_file(updated_config)

      :ok
    end

    # Inicializar ETS table para affinities (llamado desde application start)
    def init_affinity_table do
      case :ets.info(:affinity_table) do
        :undefined ->
          table = :ets.new(:affinity_table, [:named_table, :public, read_concurrency: true])
          # Cargar affinities persistidas desde archivo
          config = load_config_file()
          load_affinities_from_config(config)
          table

        _ ->
          :affinity_table
      end
    end

    defp load_affinities_from_config(config) do
      case get_in(config, ["routing", "affinities"]) do
        nil -> :ok
        affinities when is_map(affinities) ->
          Enum.each(affinities, fn {model_id, task_affinities} ->
            Enum.each(task_affinities, fn {task_type, affinity} ->
              :ets.insert(:affinity_table, {{model_id, task_type}, affinity})
            end)
          end)
        _ -> :ok
      end
    end

    @doc """
    Carga la configuración desde el archivo de configuración.
    """
    def load_config_file do
      case File.read(@config_file) do
        {:ok, contents} ->
          parse_ini(contents)

        {:error, :enoent} ->
          %{}

        {:error, reason} ->
          IO.puts("Error reading config file: #{reason}")
          %{}
      end
    end

    @doc """
    Guarda la configuración en el archivo de configuración.
    """
    def save_config_file(config) do
      dir = Path.dirname(@config_file)
      File.mkdir_p!(dir)

      ini_content = config_to_ini(config, [])
      File.write!(@config_file, ini_content)
    end

    defp config_to_ini(config, prefix \\ []) do
      config
      |> flatten_keys(prefix)
      |> Enum.map(fn {key, value} -> "#{key} = #{value}" end)
      |> Enum.join("\n")
    end

    defp flatten_keys(map, prefix) when is_map(map) do
      map
      |> Enum.flat_map(fn {key, value} ->
        new_prefix = prefix ++ [key]
        flatten_keys(value, new_prefix)
      end)
    end

    defp flatten_keys(value, prefix) when is_binary(value) or is_number(value) do
      [{Enum.join(prefix, "."), value}]
    end

    defp flatten_keys(_value, _prefix), do: []

    defp config_to_ini(_value, []), do: []

    defp parse_ini(contents) do
      lines = String.split(contents, "\n")
      sections = %{}
      current_section = nil

      lines
      |> Enum.filter(&(&1 != "" and not String.starts_with?(&1, "#")))
      |> Enum.reduce({sections, current_section}, fn line, {acc, _current_section} ->
        cond do
          String.starts_with?(line, "[") and String.ends_with?(line, "]") ->
            section = String.trim(line, "[]")
            new_acc = Map.put(acc, section, %{})
            {new_acc, section}

          String.contains?(line, "=") and current_section != nil ->
            [key, value] = String.split(line, "=", parts: 2)
            key = String.trim(key)
            value = String.trim(value)

            # Try to parse as number
            parsed_value =
              case Float.parse(value) do
                {num, ""} -> num
                _ -> value
              end

            updated_acc = Map.update(acc, current_section, %{key => parsed_value}, fn section_map ->
              Map.put(section_map, key, parsed_value)
            end)
            {updated_acc, current_section}

          true ->
            {acc, current_section}
        end
      end)
      |> elem(0)
    end

    defp parse_bool(nil, default), do: default
    defp parse_bool("true", _), do: true
    defp parse_bool("1", _), do: true
    defp parse_bool(_, default), do: default

    defp parse_float(nil, default), do: default
    defp parse_float(val, _default) when is_number(val), do: val

    defp parse_float(val, _default) when is_binary(val) do
      case Float.parse(val) do
        {num, ""} -> num
        _ -> nil
      end
    end

    defp parse_int(nil, default), do: default
    defp parse_int(val, _default) when is_integer(val), do: val

    defp parse_int(val, _default) when is_binary(val) do
      case Integer.parse(val) do
        {num, ""} -> num
        _ -> nil
      end
    end
  end

  @doc """
  Devuelve true si el cluster está habilitado.
  """
  def cluster_enabled? do
    config = Loader.get()
    Loader.config_get_in(config, [:cluster, :enabled]) == true
  end

  @doc """
  Devuelve el rol del nodo actual (:coordinator, :worker, :both).
  """
  def node_role do
    config = Loader.get()
    Loader.config_get_in(config, [:cluster, :role]) || :both
  end

  @doc """
  Devuelve el nombre del nodo actual.
  """
  def node_name do
    config = Loader.get()
    Loader.config_get_in(config, [:cluster, :node_name])
  end

  @doc """
  Devuelve la lista de nodos coordinadores configurados.
  """
  def coordinator_nodes do
    config = Loader.get()
    Loader.config_get_in(config, [:cluster, :coordinator_nodes]) || []
  end

  @doc """
  Devuelve la lista de nodos workers configurados.
  """
  def worker_nodes do
    config = Loader.get()
    Loader.config_get_in(config, [:cluster, :worker_nodes]) || []
  end

  @doc """
  Devuelve todos los nodos configurados para conectar.
  """
  def cluster_nodes do
    coordinator_nodes() ++ worker_nodes()
  end

  @doc """
  Devuelve la estrategia de descubrimiento (:static, :gossip).
  """
  def cluster_discovery do
    config = Loader.get()
    Loader.config_get_in(config, [:cluster, :discovery]) || "static"
  end

  @doc """
  Devuelve true si estamos en modo cluster.
  """
  def cluster_mode? do
    cluster_enabled?()
  end

  # === Auto-tune config ===

  @doc """
  Devuelve true si auto_tune está habilitado.
  """
  def auto_tune_enabled? do
    config = Loader.get()
    Loader.config_get_in(config, [:routing, :auto_tune]) == true
  end

  @doc """
  Devuelve la confianza mínima para auto-aplicar sugerencias.
  """
  def auto_tune_min_confidence do
    config = Loader.get()
    Loader.config_get_in(config, [:routing, :auto_tune_min_confidence]) || 0.85
  end

  @doc """
  Devuelve el número mínimo de decisiones para auto-aplicar.
  """
  def auto_tune_min_decisions do
    config = Loader.get()
    Loader.config_get_in(config, [:routing, :auto_tune_min_decisions]) || 50
  end

  @doc """
  Devuelve el intervalo de verificación en horas.
  """
  def auto_tune_check_interval_hours do
    config = Loader.get()
    Loader.config_get_in(config, [:routing, :auto_tune_check_interval_hours]) || 24
  end

  # === Cost management config ===

  @doc """
  Devuelve true si cost_management está habilitado.
  """
  def cost_management_enabled? do
    config = Loader.get()
    Loader.config_get_in(config, [:cost_management, :enabled]) == true
  end

  @doc """
  Devuelve el budget diario en USD.
  """
  def daily_usd_limit do
    config = Loader.get()
    Loader.config_get_in(config, [:cost_management, :daily_usd]) || 100.0
  end

  @doc """
  Devuelve el porcentaje de alert para el budget.
  """
  def cost_alert_at_pct do
    config = Loader.get()
    Loader.config_get_in(config, [:cost_management, :alert_at_pct]) || 80
  end

  @doc """
  Obtiene la affine para una combinación (model, task_type).
  """
  def get_affinity(model_id, task_type) do
    Loader.get_affinity(model_id, task_type)
  end

  @doc """
  Actualiza la affinity para una combinación.
  """
  def update_affinity(model_id, task_type, affinity) do
    Loader.update_affinity(model_id, task_type, affinity)
  end

  @doc """
  Carga la configuración del sistema.
  """
  def load_config do
    Loader.load_config_file()
  end

  @doc """
  Guarda la configuración del sistema.
  """
  def save_config(config) do
    Loader.save_config_file(config)
  end

  @doc """
  Obtiene el puerto HTTP.
  """
  def http_port do
    case Application.get_env(:elpaso, :http_port) do
      nil ->
        case System.get_env("ELPASO_PORT") do
          nil -> 8080
          port -> String.to_integer(port)
        end

      port when is_integer(port) ->
        port
    end
  end
end
