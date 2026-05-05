defmodule ElPaso.SchemasTest do
  use ExUnit.Case, async: true

  describe "delegated schemas" do
    test "Model.__struct__/0 delegates correctly" do
      assert ElPaso.Schemas.Model.__struct__() == ElPaso.Models.Model.__struct__()
    end

    test "Engine.__struct__/0 delegates correctly" do
      assert ElPaso.Schemas.Engine.__struct__() == ElPaso.Models.Engine.__struct__()
    end

    test "Personality.__struct__/0 delegates correctly" do
      assert ElPaso.Schemas.Personality.__struct__() == ElPaso.Models.Personality.__struct__()
    end

    test "Profile.__struct__/0 delegates correctly" do
      assert ElPaso.Schemas.Profile.__struct__() == ElPaso.Models.Profile.__struct__()
    end

    test "User.__struct__/0 delegates correctly" do
      assert ElPaso.Schemas.User.__struct__() == ElPaso.Models.User.__struct__()
    end
  end
end
