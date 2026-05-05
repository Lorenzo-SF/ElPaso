defmodule ElPaso.Repo.Migrations.AlterAutoTuneChanges do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE auto_tune_runs ALTER COLUMN changes TYPE jsonb[] USING ARRAY[changes]::jsonb[]"
  end

  def down do
    execute "ALTER TABLE auto_tune_runs ALTER COLUMN changes TYPE jsonb USING changes[1]"
  end
end
