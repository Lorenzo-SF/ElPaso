defmodule ElPaso.Repo.Migrations.SchemaHardening do
  use Ecto.Migration

  def change do
    # FIX-24: Añadir PK compuesta a routing_decisions
    alter table(:routing_decisions) do
      modify :request_id, :string, null: false, primary_key: true
    end

    # FIX-24: Añadir PK a auto_tune_runs (columna serial)
    alter table(:auto_tune_runs) do
      add :id, :bigserial, primary_key: true
    end

    # FIX-25: Añadir FK de messages → sessions
    # Primero necesitamos una constraint UNIQUE en sessions.session_id
    drop index(:sessions, [:session_id])
    create unique_index(:sessions, [:session_id])

    alter table(:messages) do
      modify :session_id, references(:sessions, column: :session_id, type: :string, on_delete: :delete_all), null: false
    end

    # FIX-26: Añadir CHECK constraints
    create constraint("models", :temperature_range, check: "temperature >= 0 AND temperature <= 2")
    create constraint("users", :valid_role, check: "role IN ('user', 'admin')")
  end
end
