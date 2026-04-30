defmodule ElPaso.Config.WizardTest do
  @moduledoc """
  Tests para ElPaso.Config.Wizard.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Config.Wizard

  describe "step_engine_type/0" do
    test "devuelve ok con valor por defecto" do
      assert {:ok, engine} = Wizard.step_engine_type()
      assert is_binary(engine)
    end
  end

  describe "step_model_config/0" do
    test "devuelve :ok" do
      assert :ok = Wizard.step_model_config()
    end
  end

  describe "step_confirm/0" do
    test "devuelve :ok" do
      assert :ok = Wizard.step_confirm()
    end
  end

  describe "setup_defaults/0" do
    test "devuelve configuración por defecto" do
      assert {:ok, config} = Wizard.setup_defaults()
      assert Map.has_key?(config, :system)
      assert Map.has_key?(config, :models)
    end
  end

  describe "start_wizard/0" do
    test "ejecuta el wizard completo" do
      assert :ok = Wizard.start_wizard()
    end
  end
end
