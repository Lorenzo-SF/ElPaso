defmodule ElPaso.HTTP.RequestParserTest do
  @moduledoc """
  Tests para ElPaso.HTTP.RequestParser.
  """

  use ExUnit.Case, async: true

  alias ElPaso.HTTP.RequestParser

  describe "parse_chat_request/1" do
    test "parsea un request válido" do
      body =
        Jason.encode!(%{
          "messages" => [%{"role" => "user", "content" => "hola"}],
          "model" => "gpt-4",
          "elpaso" => %{"session_id" => "sess-1"}
        })

      assert {:ok, parsed} = RequestParser.parse_chat_request(body)
      assert parsed.model == "gpt-4"
      assert parsed.session_id == "sess-1"
    end

    test "devuelve error para JSON inválido" do
      assert {:error, :invalid_json} = RequestParser.parse_chat_request("not json")
    end
  end
end
