defmodule ElPaso.Config.MigratorTest do
  @moduledoc """
  Tests para ElPaso.Config.Migrator.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Config.Migrator

  describe "migrate/3" do
    test "migra de 1.0 a 1.1" do
      config = %{"models" => %{"gpt-4" => %{}}}
      assert {:ok, migrated} = Migrator.migrate(config, "1.0", "1.1")
      assert Map.has_key?(migrated, "embeddings")
      assert get_in(migrated, ["models", "gpt-4", "context_spec", "tokenizer"]) == "estimate"
      assert get_in(migrated, ["meta", "version"]) == "1.1"
    end

    test "devuelve error si no hay ruta de migración" do
      assert {:error, :no_migration_path} = Migrator.migrate(%{}, "1.1", "2.0")
    end
  end

  describe "can_migrate?/2" do
    test "permite 1.0 a 1.1" do
      assert Migrator.can_migrate?("1.0", "1.1")
    end

    test "rechaza versiones desconocidas" do
      refute Migrator.can_migrate?("0.9", "1.0")
    end
  end
end