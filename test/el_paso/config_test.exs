defmodule ElPaso.ConfigTest do
  @moduledoc """
  Tests para ElPaso.Config.
  """

  use ExUnit.Case, async: false

  alias ElPaso.Config
  alias ElPaso.Config.Loader

  setup do
    Loader.init_affinity_table()
    :ok
  end

  describe "cluster_enabled?/0" do
    test "devuelve booleano" do
      assert is_boolean(Config.cluster_enabled?())
    end
  end

  describe "node_role/0" do
    test "devuelve un átomo" do
      assert is_atom(Config.node_role())
    end
  end

  describe "node_name/0" do
    test "devuelve string o nil" do
      result = Config.node_name()
      assert is_nil(result) or is_binary(result)
    end
  end

  describe "coordinator_nodes/0" do
    test "devuelve una lista" do
      assert is_list(Config.coordinator_nodes())
    end
  end

  describe "worker_nodes/0" do
    test "devuelve una lista" do
      assert is_list(Config.worker_nodes())
    end
  end

  describe "cluster_nodes/0" do
    test "devuelve una lista" do
      assert is_list(Config.cluster_nodes())
    end
  end

  describe "cluster_discovery/0" do
    test "devuelve string o atom" do
      result = Config.cluster_discovery()
      assert is_binary(result) or is_atom(result)
    end
  end

  describe "cluster_mode?/0" do
    test "devuelve booleano" do
      assert is_boolean(Config.cluster_mode?())
    end
  end

  describe "auto_tune_enabled?/0" do
    test "devuelve booleano" do
      assert is_boolean(Config.auto_tune_enabled?())
    end
  end

  describe "auto_tune_min_confidence/0" do
    test "devuelve un float" do
      assert is_float(Config.auto_tune_min_confidence())
    end
  end

  describe "auto_tune_min_decisions/0" do
    test "devuelve un entero" do
      assert is_integer(Config.auto_tune_min_decisions())
    end
  end

  describe "auto_tune_check_interval_hours/0" do
    test "devuelve un número" do
      assert is_number(Config.auto_tune_check_interval_hours())
    end
  end

  describe "cost_management_enabled?/0" do
    test "devuelve booleano" do
      assert is_boolean(Config.cost_management_enabled?())
    end
  end

  describe "daily_usd_limit/0" do
    test "devuelve un número" do
      assert is_number(Config.daily_usd_limit())
    end
  end

  describe "cost_alert_at_pct/0" do
    test "devuelve un número" do
      assert is_number(Config.cost_alert_at_pct())
    end
  end

  describe "get_affinity/2" do
    test "devuelve un float" do
      assert is_float(Config.get_affinity("model-1", "code"))
    end
  end

  describe "update_affinity/3" do
    test "devuelve :ok" do
      assert :ok = Config.update_affinity("model-1", "code", 0.8)
    end
  end

  describe "load_config/0" do
    test "devuelve un mapa" do
      assert is_map(Config.load_config())
    end
  end

  describe "http_port/0" do
    test "devuelve un entero" do
      assert is_integer(Config.http_port())
    end
  end
end
