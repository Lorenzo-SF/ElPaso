defmodule ElPaso.Engine.DispatcherTest do
  @moduledoc """
  Tests para ElPaso.Engine.Dispatcher.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Engine.Dispatcher

  describe "dispatch/1" do
    test "devuelve error porque ModelManager no está iniciado" do
      assert catch_exit(Dispatcher.dispatch(%{prompt: "hello"}))
    end
  end
end
