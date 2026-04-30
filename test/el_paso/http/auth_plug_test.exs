defmodule ElPaso.HTTP.AuthPlugTest do
  @moduledoc """
  Tests para ElPaso.HTTP.AuthPlug.
  """

  use ExUnit.Case, async: true

  alias ElPaso.HTTP.AuthPlug

  describe "init/1" do
    test "devuelve opts" do
      assert AuthPlug.init([]) == []
    end
  end

  describe "call/2" do
    test "asigna anonymous cuando auth está deshabilitado" do
      conn = %Plug.Conn{req_headers: []}
      result = AuthPlug.call(conn, [])
      assert result.assigns.current_user_id == "anonymous"
    end
  end
end
