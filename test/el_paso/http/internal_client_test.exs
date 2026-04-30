defmodule ElPaso.HTTP.InternalClientTest do
  @moduledoc """
  Tests para ElPaso.HTTP.InternalClient.
  """

  use ExUnit.Case, async: true

  alias ElPaso.HTTP.InternalClient

  describe "chat/2" do
    test "devuelve respuesta simulada" do
      assert {:ok, "response"} = InternalClient.chat("prompt", [])
    end
  end
end
