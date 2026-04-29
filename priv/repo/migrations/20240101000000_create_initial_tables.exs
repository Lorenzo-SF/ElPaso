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

      index [:name], unique: true
    end

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

      index [:name], unique: true
      index [:engine_id]
    end

    # ============================================
    # PERSONALITIES - Personalidades/roles
    # ============================================
    create table(:personalities, primary_key: false) do
      add :id, :uuid, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :string, null: false, collate: "C"
      add :description, :string
      add :system_prompt, :text, null: false
      add :vector_embedding, :vector, size: 768  # pgvector
      add :active, :boolean, default: true
      add :created_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false

      index [:name], unique: true
    end

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

      index [:name], unique: true
      index [:model_id]
      index [:engine_id]
      index [:personality_id]
    end

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

      index [:username], unique: true
      index [:api_key_hash]
    end

    # ============================================
    # SESSIONS - Sesiones de conversación
    # ============================================
    create table(:sessions, primary_key: false) do
      add :id, :uuid, default: fragment("gen_random_uuid()"), primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :profile_id, references(:profiles, type: :uuid, on_delete: :nilify_all)
      add :status, :string, default: "active", null: false
      add :context_mode, :string, default: "transparent"
      add :token_budget, :integer, default: 32768
      add :current_token_count, :integer, default: 0
      add :created_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false

      index [:user_id]
      index [:profile_id]
      index [:status]
    end

    # ============================================
    # MESSAGES - Mensajes de conversación
    # ============================================
    create table(:messages, primary_key: false) do
      add :id, :uuid, default: fragment("gen_random_uuid()"), primary_key: true
      add :session_id, references(:sessions, type: :uuid, on_delete: :delete_all), null: false
      add :role, :string, null: false
      add :content, :text, null: false
      add :model_id, :string
      add :token_estimate, :integer, default: 0
      add :vector_embedding, :vector, size: 768  # pgvector
      add :sequence_number, :integer, null: false
      add :created_at, :utc_datetime, null: false

      index [:session_id]
      index [:role]
    end

    # ============================================
    # ROUTING DECISIONS - Decisiones de enrutamiento
    # ============================================
    create table(:routing_decisions, primary_key: false) do
      add :id, :uuid, default: fragment("gen_random_uuid()"), primary_key: true
      add :session_id, references(:sessions, type: :uuid, on_delete: :delete_all)
      add :request_id, :string, null: false
      add :selected_model, :string, null: false
      add :runner_up, :string
      add :features, :map, default: "{}"
      add :scores, :map, default: "{}"
      add :reason, :text
      add :outcome, :string, default: "pending"  # success, retry, error
      add :latency_ms, :integer
      add :decision_latency_us, :integer
      add :created_at, :utc_datetime, null: false

      index [:session_id]
      index [:request_id], unique: true
      index [:selected_model]
      index [:outcome]
      index [:features], using: :gin
      index [:scores], using: :gin
    end

    # ============================================
    # CONVERSATION SUMMARIES - Resúmenes de conversación
    # ============================================
    create table(:conversation_summaries, primary_key: false) do
      add :id, :uuid, default: fragment("gen_random_uuid()"), primary_key: true
      add :session_id, references(:sessions, type: :uuid, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :covers_until_message_id, :uuid
      add :token_estimate, :integer, default: 0
      add :generated_by_model, :string
      add :generated_at, :utc_datetime, null: false

      index [:session_id]
    end

    # ============================================
    # API USAGE - Uso de API y costes
    # ============================================
    create table(:api_usage, primary_key: false) do
      add :id, :uuid, default: fragment("gen_random_uuid()"), primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :model_id, :string, null: false
      add :date, :date, null: false
      add :input_tokens, :integer, default: 0
      add :output_tokens, :integer, default: 0
      add :cost_usd, :decimal, default: "0.00"
      add :created_at, :utc_datetime, null: false

      index [:user_id]
      index [:model_id]
      index [:date]
    end

    # ============================================
    # BENCHMARKS - Resultados de benchmarks
    # ============================================
    create table(:benchmarks, primary_key: false) do
      add :id, :uuid, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :string, null: false
      add :model_id, references(:models, type: :uuid, on_delete: :nilify_all)
      add :engine_id, references(:engines, type: :uuid, on_delete: :nilify_all)
      add :prompt, :text
      add :latency_ms, :integer
      add :tokens_per_sec, :float
      add :quality_score, :float
      add :config, :map, default: "{}"
      add :created_at, :utc_datetime, null: false

      index [:model_id]
      index [:engine_id]
    end

    # ============================================
    # AUTO-TUNE RUNS - Registros de auto-tune
    # ============================================
    create table(:auto_tune_runs, primary_key: false) do
      add :id, :uuid, default: fragment("gen_random_uuid()"), primary_key: true
      add :applied, :integer, default: 0
      add :changes, :map, default: "[]"
      add :created_at, :utc_datetime, null: false
    end

    # ============================================
    # CREATE IVFFLAT INDEX FOR EMBEDDINGS
    # ============================================
    execute("CREATE EXTENSION IF NOT EXISTS vector")

    # Create indexes for pgvector after tables are created
    execute("""
    CREATE INDEX IF NOT EXISTS idx_messages_vector_embedding
    ON messages USING ivfflat (vector_embedding vector_l2_ops) WITH (lists = 100);
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS idx_personalities_vector_embedding
    ON personalities USING ivfflat (vector_embedding vector_l2_ops) WITH (lists = 100);
    """)
  end
end
