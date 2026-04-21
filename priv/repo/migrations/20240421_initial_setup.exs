defmodule ElPaso.Repo.Migrations.InitialSetup do
  use Ecto.Migration

  def change do
    # ==============================================================
    # Tabla: sessions
    # ==============================================================
    create table(:sessions, primary_key: false) do
      add :session_id, :string, null: false
      add :user_id, :string
      add :model_id, :string
      add :context_mode, :string, default: "transparent"
      add :status, :string, default: "active"
      
      add :inserted_at, :utc_datetime
      add :updated_at, :utc_datetime
    end

    create index(:sessions, [:session_id])
    create index(:sessions, [:user_id])
    create index(:sessions, [:status])

    # ==============================================================
    # Tabla: messages
    # ==============================================================
    create table(:messages, primary_key: false) do
      add :session_id, :string, null: false
      add :role, :string, null: false  # "user" | "assistant"
      add :content, :text, null: false
      add :model_id, :string
      add :tokens, :integer
      
      # No timestamps() - usamos created_at personalizado
      add :inserted_at, :utc_datetime
      add :updated_at, :utc_datetime
    end

    create index(:messages, [:session_id])
    create index(:messages, [:inserted_at])

    # ==============================================================
    # Tabla: conversation_summaries
    # ==============================================================
    create table(:conversation_summaries, primary_key: false) do
      add :session_id, :string, null: false
      add :summary, :text, null: false
      add :summary_tokens, :integer
      add :window_start, :utc_datetime
      add :window_end, :utc_datetime
      
      add :inserted_at, :utc_datetime
      add :updated_at, :utc_datetime
    end

    create index(:conversation_summaries, [:session_id])
    create index(:conversation_summaries, [:window_end])

    # ==============================================================
    # Tabla: routing_decisions (V2.2 - aprendizaje adaptativo)
    # ==============================================================
    create table(:routing_decisions, primary_key: false) do
      # Identificación
      add :request_id, :string, null: false
      add :session_id, :string, null: false
      
      # Decisión de routing
      add :model_id, :string, null: false
      add :task_type, :string, null: false  # "code" | "reasoning" | "summarization" | "question_answer" | "creative" | "translation" | "unknown"
      add :selected_model, :string, null: false
      add :runner_up, :string
      
      # Features del request
      add :token_estimate, :integer
      add :complexity_score, :float
      add :language, :string
      
      # Scores y razón
      add :scores, :map  # %{model_id => score}
      add :reason, :string
      
      # Resultado (para análisis)
      add :outcome, :string  # "success" | "retry" | "error" | "timeout"
      add :decision_latency_us, :integer
      
      # Timestamps
      add :decided_at, :utc_datetime, null: false
      
      add :inserted_at, :utc_datetime
      add :updated_at, :utc_datetime
    end

    create index(:routing_decisions, [:session_id])
    create index(:routing_decisions, [:model_id])
    create index(:routing_decisions, [:task_type])
    create index(:routing_decisions, [:decided_at])
    create index(:routing_decisions, [:outcome])
    
    # Composite indexes para análisis de tendencias
    create index(:routing_decisions, [:model_id, :task_type])
    create index(:routing_decisions, [:decided_at, :outcome])

    # ==============================================================
    # Tabla: auto_tune_runs (V2.2)
    # ==============================================================
    create table(:auto_tune_runs, primary_key: false) do
      add :applied_count, :integer, null: false
      add :changes, :map  # [%{model_id, task_type, previous_affinity, new_affinity}]
      add :trigger, :string, default: "scheduled"  # "scheduled" | "manual"
      
      add :inserted_at, :utc_datetime
      add :updated_at, :utc_datetime
    end

    create index(:auto_tune_runs, [:inserted_at])

    # ==============================================================
    # Tabla: api_usage (V3.0 - cost management)
    # ==============================================================
    create table(:api_usage, primary_key: false) do
      add :user_id, :string, null: false
      add :model_id, :string, null: false
      add :date, :date, null: false
      add :input_tokens, :bigint, default: 0
      add :output_tokens, :bigint, default: 0
      add :cost_usd, :decimal, precision: 10, scale: 6
      add :request_count, :integer, default: 0
      
      add :inserted_at, :utc_datetime
      add :updated_at, :utc_datetime
    end

    create index(:api_usage, [:user_id, :date])
    create index(:api_usage, [:model_id, :date])
    create index(:api_usage, [:date])

    # ==============================================================
    # Tabla: model_pricing (V3.0)
    # ==============================================================
    create table(:model_pricing, primary_key: false) do
      add :model_id, :string, null: false
      add :input_price_per_1k, :decimal, precision: 10, scale: 6, null: false
      add :output_price_per_1k, :decimal, precision: 10, scale: 6, null: false
      add :valid_from, :date, null: false
      add :valid_until, :date
      
      add :inserted_at, :utc_datetime
      add :updated_at, :utc_datetime
    end

    create index(:model_pricing, [:model_id])
    create index(:model_pricing, [:valid_from])

    # ==============================================================
    # Tabla: sessions_shared (V2.1 - clustering)
    # ==============================================================
    create table(:sessions_shared, primary_key: false) do
      add :session_id, :string, null: false
      add :node, :string, null: false
      add :last_accessed_at, :utc_datetime, null: false
      
      add :inserted_at, :utc_datetime
      add :updated_at, :utc_datetime
    end

    create index(:sessions_shared, [:session_id])
    create index(:sessions_shared, [:node])
  end
end