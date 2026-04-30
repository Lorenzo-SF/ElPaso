defmodule ElPaso.HTTP.AdminAuthPlugTest do
  @moduledoc """
  Tests para ElPaso.HTTP.AdminAuthPlug.
  """

  use ExUnit.Case, async: true

  alias ElPaso.HTTP.AdminAuthPlug

  describe "init/1" do
    test "devuelve opts" do
      assert AdminAuthPlug.init([]) == []
    end
  end

  describe "call/2" do
    test "devuelve 401 sin token" do
      conn = %Plug.Conn{req_headers: [], status: nil}
      result = AdminAuthPlug.call(conn, [])
      assert result.halted
      assert result.status == 401
    end
  end
end
