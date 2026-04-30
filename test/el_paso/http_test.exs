defmodule ElPaso.HTTPTest do
  @moduledoc """
  Tests para ElPaso.HTTP.
  """

  use ExUnit.Case, async: true

  alias ElPaso.HTTP

  test "start/2 devuelve :ok" do
    assert :ok = HTTP.start(:normal, [])
  end
end
