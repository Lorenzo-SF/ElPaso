defmodule ElPaso.Security.JWTTest do
  use ExUnit.Case, async: true

  alias ElPaso.Security.JWT

  describe "generate_token/2" do
    test "produce un string no vacío" do
      token = JWT.generate_token("test-user", :user)
      assert is_binary(token)
      assert String.length(token) > 0
    end
  end

  describe "verify_token/1" do
    test "acepta un token válido" do
      token = JWT.generate_token("test-user", :user)
      assert {:ok, %{user_id: "test-user", role: :user}} = JWT.verify_token(token)
    end

    test "rechaza token manipulado" do
      token = JWT.generate_token("test-user", :user)
      tampered = token <> "tampered"
      assert {:error, :invalid} = JWT.verify_token(tampered)
    end
  end

  describe "extract_from_conn/1" do
    test "extrae token de header Authorization" do
      conn = %Plug.Conn{}
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer test-token-123")
      assert JWT.extract_from_conn(conn) == "test-token-123"
    end

    test "retorna nil sin header" do
      conn = %Plug.Conn{}
      assert JWT.extract_from_conn(conn) == nil
    end
  end
end
