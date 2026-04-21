defmodule ElPaso.Context.Migrations do
  @moduledoc """
  Migraciones para las tablas del contexto.
  
  Este módulo define las migraciones Ecto para las tablas necesarias en V1.0.
  """

  # Esta implementación sería parte de las migraciones, pero como estamos en el código base,
  # proporcionamos una estructura de ejemplo que se convertiría en migraciones reales
  
  @doc """
  Creación de la tabla de sesiones.
  """
  def create_sessions_table() do
    # Esta sería una migración real en Ecto
    
    """
    CREATE TABLE sessions (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      context_mode TEXT NOT NULL DEFAULT 'transparent',
      metadata JSONB DEFAULT '{}'::jsonb
    );
    
    CREATE INDEX idx_sessions_last_active ON sessions(last_active_at);
    """
  end

  @doc """
  Creación de la tabla de mensajes.
  """
  def create_messages_table() do
    # Esta sería una migración real en Ecto
    
    """
    CREATE TABLE messages (
      id BIGSERIAL PRIMARY KEY,
      session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
      sequence_number INTEGER NOT NULL,
      role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
      content TEXT NOT NULL,
      token_estimate INTEGER NOT NULL DEFAULT 0,
      model_id TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      archived_at TIMESTAMPTZ,
      embedding vector(768)
    );
    
    CREATE INDEX idx_messages_session_seq ON messages(session_id, sequence_number);
    CREATE INDEX idx_messages_session_active ON messages(session_id, archived_at) WHERE archived_at IS NULL;
    CREATE INDEX idx_messages_embedding ON messages USING ivfflat (embedding vector_cosine_ops) WHERE embedding IS NOT NULL;
    """
  end

  @doc """
  Creación de la tabla de resúmenes.
  """
  def create_summaries_table() do
    # Esta sería una migración real en Ecto
    
    """
    CREATE TABLE conversation_summaries (
      id BIGSERIAL PRIMARY KEY,
      session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
      content TEXT NOT NULL,
      covers_until_message_id BIGINT REFERENCES messages(id),
      token_estimate INTEGER NOT NULL DEFAULT 0,
      generated_by_model TEXT NOT NULL,
      generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    
    CREATE INDEX idx_summaries_session ON conversation_summaries(session_id, generated_at DESC);
    """
  end

  @doc """
  Creación de la tabla de decisiones de enrutamiento.
  """
  def create_routing_decisions_table() do
    # Esta sería una migración real en Ecto
    
    """
    CREATE TABLE routing_decisions (
      request_id TEXT PRIMARY KEY,
      session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
      selected_model TEXT NOT NULL,
      runner_up TEXT,
      task_type TEXT NOT NULL,
      complexity_score FLOAT NOT NULL,
      token_estimate INTEGER NOT NULL,
      feature_vector JSONB NOT NULL,
      scores JSONB NOT NULL,
      reason TEXT NOT NULL,
      outcome TEXT,
      latency_ms INTEGER,
      decided_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    
    CREATE INDEX idx_routing_session ON routing_decisions(session_id, decided_at DESC);
    CREATE INDEX idx_routing_model_task ON routing_decisions(selected_model, task_type);
    """
  end
end