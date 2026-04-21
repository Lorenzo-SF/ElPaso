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
    _metadata = Keyword.get(opts, :metadata, %{})

    # Crear la sesión en PostgreSQL
    session = %Session{
      context_mode: context_mode,
      user_id: Keyword.get(opts, :user_id),
      model_id: Keyword.get(opts, :model_id),
      status: Keyword.get(opts, :status, "active")
    }

    case ElPaso.Context.Repo.insert(session) do
      {:ok, inserted_session} -> {:ok, inserted_session.id}
      error -> error
    end
  end

  @doc """
  Actualiza la fecha de última actividad de una sesión.
  """
  def touch_session(_session_id) do
    # Actualizar la fecha en PostgreSQL
    :ok
  end

  @doc """
  Elimina una sesión y todos sus mensajes.
  """
  def delete_session(_session_id) do
    # Eliminar la sesión en PostgreSQL (CASCADE eliminará los mensajes)
    :ok
  end

  @doc """
  Guarda un mensaje en la base de datos.
  """
  def save_message(_session_id, _role, _content, _opts) do
    # Guardar el mensaje en PostgreSQL

    # Esta implementación es simplificada - en producción se usaría Ecto

    {:ok, "message_id"}
  end

  @doc """
  Guarda un embedding para un mensaje.
  """
  def save_embedding(_message_id, _vector) do
    # Guardar el embedding en PostgreSQL

    # Esta implementación es simplificada - en producción se usaría Ecto

    :ok
  end

  @doc """
  Obtiene los últimos mensajes de la ventana activa.
  """
  def get_window(_session_id, _limit) do
    # Obtener los últimos mensajes no archivados ordenados por sequence_number ASC

    {:ok, []}
  end

  @doc """
  Archiva mensajes antes de un mensaje específico.
  """
  def archive_messages_before(_session_id, _message_id) do
    # Marcar como archivados todos los mensajes con id <= message_id

    {:ok, 0}
  end

  @doc """
  Busca mensajes similares semánticamente.
  """
  def search_semantic(_session_id, _embedding, _limit) do
    # Búsqueda coseno en mensajes archivados; devuelve los `limit` más similares
    # Esta implementación es simplificada

    {:error, :pgvector_unavailable}
  end

  @doc """
  Obtiene el último resumen de conversación.
  """
  def get_latest_summary(_session_id) do
    # Obtener el último resumen del historial

    {:error, :not_found}
  end

  @doc """
  Guarda un resumen de conversación.
  """
  def save_summary(_session_id, _content, _opts) do
    # Guardar el resumen en PostgreSQL

    # Esta implementación es simplificada - en producción se usaría Ecto

    {:ok, "summary_id"}
  end

  @doc """
  Guarda una decisión de enrutamiento.
  """
  def save_routing_decision(_decision) do
    # Guardar la decisión en la tabla routing_decisions

    :ok
  end

  @doc """
  Obtiene las decisiones de enrutamiento.
  """
  def query_routing_decisions(_opts) do
    # Esta implementación es simplificada - en producción se usaría Ecto

    # Devolver datos simulados
    [
      %{
        selected_model: "fast",
        runner_up: "heavy",
        task_type: "question_answer",
        latency_ms: 120,
        outcome: "success"
      },
      %{
        selected_model: "heavy",
        runner_up: "fast",
        task_type: "code",
        latency_ms: 350,
        outcome: "success"
      }
    ]
  end

  @doc """
  Actualiza el resultado de una decisión de enrutamiento.
  """
  def update_routing_outcome(_request_id, _outcome, _latency_ms) do
    # Actualizar la decisión con información del resultado

    :ok
  end

  # Funciones auxiliares para el manejo de contextos
  @doc """
  Obtiene las tres capas del contexto para construcción.
  """
  def get_context_layers(_session_id, _context_spec) do
    # Esta función se implementará en el Manager
    {:ok,
     %{
       summary: nil,
       window: [],
       semantic: []
     }}
  end

  @doc """
  Obtiene una sesión.
  """
  def get_session(_session_id) do
    # Esta implementación es simplificada

    {:error, :not_found}
  end

  @doc """
  Obtiene todos los mensajes de una sesión.
  """
  def get_all_messages(_session_id) do
    # Esta implementación es simplificada

    {:ok, []}
  end
end
