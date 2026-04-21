defmodule ElPaso.Context.Storage do
  @moduledoc """
  Módulo de almacenamiento del contexto en PostgreSQL.
  
  Este módulo gestiona toda la persistencia del contexto en PostgreSQL (datos de largo plazo)
  y ETS (caché de acceso rápido). Es puramente de acceso a datos: no tiene lógica de negocio.
  """

  alias ElPaso.Context.Schemas.Session
  alias ElPaso.Context.Schemas.Message
  alias ElPaso.Context.Schemas.ConversationSummary
  alias ElPaso.Context.Schemas.RoutingDecision

  @doc """
  Crea una nueva sesión.
  """
  def create_session(opts) do
    context_mode = Keyword.get(opts, :context_mode, "transparent")
    metadata = Keyword.get(opts, :metadata, %{})

    # Crear la sesión en PostgreSQL
    session = %Session{
      context_mode: context_mode,
      metadata: metadata
    }

    case ElPaso.Context.Repo.insert(session) do
      {:ok, inserted_session} -> {:ok, inserted_session.id}
      error -> error
    end
  end

  @doc """
  Actualiza la fecha de última actividad de una sesión.
  """
  def touch_session(session_id) do
    # Actualizar la fecha en PostgreSQL
    case ElPaso.Context.Repo.get(Session, session_id) do
      nil -> {:error, :not_found}
      session ->
        updated_session = %{session | last_active_at: DateTime.utc_now()}
        ElPaso.Context.Repo.update(updated_session)
    end
  end

  @doc """
  Elimina una sesión y todos sus mensajes.
  """
  def delete_session(session_id) do
    # Eliminar la sesión en PostgreSQL (CASCADE eliminará los mensajes)
    case ElPaso.Context.Repo.get(Session, session_id) do
      nil -> {:error, :not_found}
      session ->
        ElPaso.Context.Repo.delete(session)
    end
  end

  @doc """
  Guarda un mensaje en la base de datos.
  """
  def save_message(session_id, role, content, opts) do
    model_id = Keyword.get(opts, :model_id, nil)
    token_estimate = Keyword.get(opts, :token_estimate, 0)

    message = %Message{
      session_id: session_id,
      role: role,
      content: content,
      model_id: model_id,
      token_estimate: token_estimate
    }

    case ElPaso.Context.Repo.insert(message) do
      {:ok, inserted_message} -> {:ok, inserted_message.id}
      error -> error
    end
  end

  @doc """
  Obtiene los últimos mensajes de la ventana activa.
  """
  def get_window(session_id, limit) do
    # Obtener los últimos mensajes no archivados ordenados por sequence_number ASC
    query = from(m in Message,
      where: m.session_id == ^session_id and is_nil(m.archived_at),
      order_by: [asc: m.sequence_number],
      limit: ^limit)

    case ElPaso.Context.Repo.all(query) do
      messages -> {:ok, messages}
    end
  end

  @doc """
  Archiva mensajes antes de un mensaje específico.
  """
  def archive_messages_before(session_id, message_id) do
    # Marcar como archivados todos los mensajes con id <= message_id
    query = from(m in Message,
      where: m.session_id == ^session_id and m.id <= ^message_id and is_nil(m.archived_at))

    case ElPaso.Context.Repo.update_all(query, set: [archived_at: DateTime.utc_now()]) do
      {count, _} -> {:ok, count}
    end
  end

  @doc """
  Busca mensajes similares semánticamente.
  """
  def search_semantic(session_id, embedding, limit) do
    # Búsqueda coseno en mensajes archivados; devuelve los `limit` más similares
    # Esta implementación es simplificada - en producción usaría pgvector
    
    # Para este prototipo, devolvemos un error indicando que la funcionalidad no está implementada aún
    {:error, :pgvector_unavailable}
  end

  @doc """
  Obtiene el último resumen de conversación.
  """
  def get_latest_summary(session_id) do
    # Obtener el último resumen del historial
    query = from(s in ConversationSummary,
      where: s.session_id == ^session_id,
      order_by: [desc: s.generated_at],
      limit: 1)

    case ElPaso.Context.Repo.one(query) do
      nil -> {:error, :not_found}
      summary -> {:ok, summary}
    end
  end

  @doc """
  Guarda un resumen de conversación.
  """
  def save_summary(session_id, content, opts) do
    covers_until_message_id = Keyword.get(opts, :covers_until_message_id, nil)
    token_estimate = Keyword.get(opts, :token_estimate, 0)
    generated_by_model = Keyword.get(opts, :generated_by_model, "default")

    summary = %ConversationSummary{
      session_id: session_id,
      content: content,
      covers_until_message_id: covers_until_message_id,
      token_estimate: token_estimate,
      generated_by_model: generated_by_model
    }

    case ElPaso.Context.Repo.insert(summary) do
      {:ok, inserted_summary} -> {:ok, inserted_summary}
      error -> error
    end
  end

  @doc """
  Guarda una decisión de enrutamiento.
  """
  def save_routing_decision(decision) do
    # Guardar la decisión en la tabla routing_decisions
    case ElPaso.Context.Repo.insert(decision) do
      {:ok, inserted_decision} -> :ok
      error -> error
    end
  end

  @doc """
  Actualiza el resultado de una decisión de enrutamiento.
  """
  def update_routing_outcome(request_id, outcome, latency_ms) do
    # Actualizar la decisión con información del resultado
    case ElPaso.Context.Repo.get(RoutingDecision, request_id) do
      nil -> {:error, :not_found}
      decision ->
        updated_decision = %{
          decision | 
          outcome: outcome,
          latency_ms: latency_ms
        }
        ElPaso.Context.Repo.update(updated_decision)
    end
  end

  # Funciones auxiliares para el manejo de contextos
  @doc """
  Obtiene las tres capas del contexto para construcción.
  """
  def get_context_layers(session_id, context_spec) do
    # Esta función se implementará en el Manager
    {:ok, %{
      summary: nil,
      window: [],
      semantic: []
    }}
  end
end