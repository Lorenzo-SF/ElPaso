defmodule ElPaso.Repo.Migrations.DecisionEngineV4 do
  use Ecto.Migration

  def up do
    # ═══════════════════════════════════════════════════════════════════════
    # 1. Añadir campos semánticos a personalities
    # ═══════════════════════════════════════════════════════════════════════
    alter table(:personalities) do
      add :semantic_description, :text
      add :embedding, :vector
      add :regex_patterns, {:array, :string}, default: []
      add :min_confidence, :float, default: 0.5
      add :cooldown_ms, :integer, default: 0
    end

    # Índice ivfflat para búsqueda de embeddings por cosine similarity
    execute """
    CREATE INDEX IF NOT EXISTS idx_personalities_embedding
    ON personalities USING ivfflat (embedding vector_cosine_ops) WITH (lists = 10);
    """

    # ═══════════════════════════════════════════════════════════════════════
    # 2. Actualizar personalidades existentes con semantic_description
    # ═══════════════════════════════════════════════════════════════════════
    execute """
    UPDATE personalities
    SET semantic_description = COALESCE(description, name)
    WHERE semantic_description IS NULL;
    """

    # ═══════════════════════════════════════════════════════════════════════
    # 3. Añadir campos de tracking de decisiones a routing_decisions
    # ═══════════════════════════════════════════════════════════════════════
    alter table(:routing_decisions) do
      add :personality_name, :string
      add :decision_layer, :string
      add :confidence, :float
    end
  end

  def down do
    # Eliminar índice de embeddings
    execute "DROP INDEX IF EXISTS idx_personalities_embedding;"

    # Eliminar campos de personalities
    alter table(:personalities) do
      remove :semantic_description
      remove :embedding
      remove :regex_patterns
      remove :min_confidence
      remove :cooldown_ms
    end

    # Eliminar campos de routing_decisions
    alter table(:routing_decisions) do
      remove :personality_name
      remove :decision_layer
      remove :confidence
    end
  end
end
