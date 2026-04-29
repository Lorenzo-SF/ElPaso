defmodule ElPaso.Repo.Migrations.CreateInitialTables do
  use Ecto.Migration

  def change do
    # ============================================
    # ENGINES - Motores de inferencia
    # ============================================
    create table(:engines, primary_key: false) do
      add :id, :uuid, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :string, null: false, collate: "C"
      add :adapter, :string, null: false
      add :base_url, :string, null: false
      add :api_key, :string
      add :config, :map, default: "{}"
      add :active, :boolean, default: true
      add :health_status, :string, default: "unknown"
      add :last_health_check, :utc_datetime
      add :created_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
    end

    create index(:engines, [:name], unique: true)

    # ============================================
    # MODELS - Modelos de inferencia
    # ============================================
    create table(:models, primary_key: false) do
      add :id, :uuid, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :string, null: false, collate: "C"
      add :engine_id, references(:engines, type: :uuid, on_delete: :nilify_all)
      add :url, :string
      add :api_key, :string
      add :config, :map, default: "{}"
      add :active, :boolean, default: true
      add :max_tokens, :integer, default: 4096
      add :temperature, :float, default: 0.7
      add :top_p, :float, default: 1.0
      add :description, :string
      # Routing config
      add :task_affinity, :map, default: "{}"
      add :complexity_ceiling, :float, default: 1.0
      add :cold_start_estimate_ms, :integer, default: 5000
      add :ram_mb, :integer
      add :vram_mb, :integer
      add :created_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
    end

    create index(:models, [:name], unique: true)
    create index(:models, [:engine_id])

    # ============================================
    # PERSONALITIES - Personalidades/roles
    # ============================================
    create table(:personalities, primary_key: false) do
      add :id, :uuid, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :string, null: false, collate: "C"
      add :description, :string
      add :system_prompt, :text, null: false
      add :active, :boolean, default: true
      add :created_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
    end

    create index(:personalities, [:name], unique: true)

    # ============================================
    # PROFILES - Conjuntos modelo+engine+personalidad
    # ============================================
    create table(:profiles, primary_key: false) do
      add :id, :uuid, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :string, null: false, collate: "C"
      add :model_id, references(:models, type: :uuid, on_delete: :nilify_all)
      add :engine_id, references(:engines, type: :uuid, on_delete: :nilify_all)
      add :personality_id, references(:personalities, type: :uuid, on_delete: :nilify_all)
      add :config, :map, default: "{}"
      add :active, :boolean, default: true
      add :description, :string
      add :created_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
    end

    create index(:profiles, [:name], unique: true)
    create index(:profiles, [:model_id])
    create index(:profiles, [:engine_id])
    create index(:profiles, [:personality_id])

    # ============================================
    # USERS - Usuarios del sistema
    # ============================================
    create table(:users, primary_key: false) do
      add :id, :uuid, default: fragment("gen_random_uuid()"), primary_key: true
      add :username, :string, null: false, collate: "C"
      add :api_key_hash, :string
      add :role, :string, default: "user", null: false
      add :budget_daily, :decimal, default: "100.00"
      add :active, :boolean, default: true
      add :created_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
    end

    create index(:users, [:username], unique: true)
    create index(:users, [:api_key_hash])

    # Note: sessions table already exists from InitialSetup migration
    # so we don't recreate it here
  end
end