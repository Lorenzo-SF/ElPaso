defmodule ElPaso.HTTP.ServerTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias ElPaso.HTTP.Server

  @opts Server.init([])

  describe "GET /status" do
    test "devuelve status ok" do
      conn = conn(:get, "/status") |> Server.call(@opts)
      assert conn.status == 200
      assert %{"status" => "ok"} = Jason.decode!(conn.resp_body)
    end
  end

  describe "GET /metrics" do
    test "devuelve métricas en texto plano" do
      conn = conn(:get, "/metrics") |> Server.call(@opts)
      assert conn.status == 200
      assert String.contains?(conn.resp_body, "elpaso_")
    end
  end

  describe "GET /dashboard" do
    test "devuelve HTML" do
      conn = conn(:get, "/dashboard") |> Server.call(@opts)
      assert conn.status == 200
    end
  end

  describe "POST /auth/token" do
    test "rechaza sin credenciales" do
      conn = conn(:post, "/auth/token", Jason.encode!(%{}))
             |> put_req_header("content-type", "application/json")
             |> Server.call(@opts)
      assert conn.status == 401
    end
  end

  describe "POST /v1/messages" do
    test "rechaza body inválido" do
      conn = conn(:post, "/v1/messages", "not json")
             |> put_req_header("content-type", "application/json")
             |> Server.call(@opts)
      # Con Plug.Parsers, esto dará error de parseo
      assert conn.status in [400, 500]
    end
  end

  describe "admin endpoints" do
    test "GET /admin/sessions sin token retorna 403" do
      conn = conn(:get, "/admin/sessions") |> Server.call(@opts)
      assert conn.status == 403
    end
  end
end
