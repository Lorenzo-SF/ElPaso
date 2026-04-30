defmodule ElPaso.ModelsTest do
  @moduledoc """
  Tests para ElPaso.Models.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Models

  describe "all_models/0" do
    test "devuelve lista vacía" do
      assert Models.all_models() == []
    end
  end

  describe "create_model/1" do
    test "devuelve not_implemented" do
      assert {:error, :not_implemented} = Models.create_model(%{})
    end
  end

  describe "all_engines/0" do
    test "devuelve lista vacía" do
      assert Models.all_engines() == []
    end
  end

  describe "create_engine/1" do
    test "devuelve not_implemented" do
      assert {:error, :not_implemented} = Models.create_engine(%{})
    end
  end
end
