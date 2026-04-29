defmodule ElPaso.Context.ManagerTest do
  @moduledoc """
  Tests para ElPaso.Context.Manager.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Context.Manager

  describe "active_session_count/0" do
    test "devuelve un entero" do
      assert is_integer(Manager.active_session_count())
    end
  end
end
