defmodule ElPaso.Config.DiffTest do
  @moduledoc """
  Tests para ElPaso.Config.Diff.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Config.Diff

  describe "diff/2" do
    test "devuelve struct Diff vacío" do
      assert %Diff{} = Diff.diff(%{}, %{})
    end
  end

  describe "flatten/1" do
    test "devuelve mapa vacío" do
      assert %{} = Diff.flatten(%{a: 1})
    end
  end
end
