defmodule ElPaso.Domain.AutoTunerTest do
  @moduledoc """
  Tests para ElPaso.Domain.AutoTuner.
  """

  use ExUnit.Case, async: false

  alias ElPaso.Domain.AutoTuner

  setup do
    start_supervised!({AutoTuner, []})
    :ok
  end

  describe "run_now/0" do
    test "ejecuta auto-tune sin errores" do
      assert :ok = AutoTuner.run_now()
    end
  end
end
