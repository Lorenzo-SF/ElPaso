defmodule ElPaso.Security.JWTTest do
  @moduledoc """
  Tests para ElPaso.Security.JWT.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Security.JWT

  describe "generate_token/2" do
    test "genera un token string" do
      token = JWT.generate_token("user-1", :user)
      assert is_binary(token)
      assert String.split(token, ".") |> length() == 3
    end

    test "genera token para admin" do
      token = JWT.generate_token("admin-1", :admin)
      assert is_binary(token)
    end
  end

  describe "verify_token/1" do
    test "verifica un token válido" do
      token = JWT.generate_token("user-1", :user)
      assert {:ok, %{user_id: "user-1", role: :user}} = JWT.verify_token(token)
    end

    test "rechaza un token inválido" do
      assert {:error, :invalid} = JWT.verify_token("invalid.token.here")
    end

    test "rechaza un token expirado" do
      # Forzar un token expirado generando claims manualmente
      secret = Application.get_env(:elpaso, :jwt_secret, "dev-secret-change-in-prod")
      claims = %{"sub" => "user-1", "role" => "user", "iat" => 0, "exp" => 1}
      {_jws, jwt} = JOSE.JWT.sign(JOSE.JWK.from_oct(secret), %{"alg" => "HS256"}, claims)
      expired = JOSE.JWS.compact(jwt) |> elem(1)
      assert {:error, :expired} = JWT.verify_token(expired)
    end
  end

  describe "extract_from_conn/1" do
    test "extrae Bearer token" do
      conn = %Plug.Conn{req_headers: [{"authorization", "Bearer abc123"}]}
      assert JWT.extract_from_conn(conn) == "abc123"
    end

    test "extrae token legacy sin Bearer" do
      conn = %Plug.Conn{req_headers: [{"authorization", "legacy.token"}]}
      assert JWT.extract_from_conn(conn) == "legacy.token"
    end

    test "devuelve nil sin header" do
      conn = %Plug.Conn{req_headers: []}
      assert JWT.extract_from_conn(conn) == nil
    end
  end
end