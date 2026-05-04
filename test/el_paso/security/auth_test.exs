defmodule ElPaso.Security.AuthTest do
  use ExUnit.Case, async: false
  import Ecto.Query

  alias ElPaso.Security.Auth

  describe "authenticate/1" do
    test "con auth deshabilitada retorna anonymous" do
      # Asume que auth está deshabilitada por defecto en test
      assert {:ok, "anonymous"} = Auth.authenticate(nil)
    end

    test "con api_key inválida retorna error" do
      assert {:error, :invalid_api_key} = Auth.authenticate("invalid-key-123")
    end
  end

  describe "extract_api_key/1" do
    test "extrae api key de header Bearer" do
      conn = %Plug.Conn{}
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer sk-test-123")
      assert Auth.extract_api_key(conn) == "sk-test-123"
    end

    test "retorna nil sin header" do
      conn = %Plug.Conn{}
      assert Auth.extract_api_key(conn) == nil
    end
  end
end
