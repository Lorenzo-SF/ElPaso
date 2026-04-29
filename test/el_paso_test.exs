defmodule ElPasoTest do
  use ExUnit.Case
  doctest ElPaso

  test "greets the world" do
    assert ElPaso.hello() == :world
  end

  test "version está definida" do
    assert is_binary(ElPaso.MixProject.project()[:version])
  end
end
