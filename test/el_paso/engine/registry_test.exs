defmodule ElPaso.Engine.RegistryTest do
  @moduledoc """
  Tests para ElPaso.Engine.Registry.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Engine.Registry

  describe "start_link/1" do
    test "inicia el registro" do
      assert {:ok, _pid} = Registry.start_link([])
    end
  end
end
