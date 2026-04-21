defmodule ElPaso.Context.Manager do
  @moduledoc """
  Coordinador del ciclo de vida del contexto de sesión.
  
  Este módulo coordina el estado activo de las sesiones. A diferencia de Context.Storage (que solo persiste),
  el Manager mantiene el estado en memoria (ETS), toma decisiones sobre cuándo comprimir,
  y dispara los jobs de resumen.
  """

  use GenServer

  alias ElPaso.Context.Storage
  alias ElPaso.Context.PrefixManager
  alias ElPaso.Context.Schemas.Message

  # Estructura para el estado de sesión en ETS
  defmodule SessionState do
    @moduledoc """
    Estructura que representa el estado de una sesión en memoria.
    """

    defstruct [
      :session_id,
      :context_mode,
      :window,
      :window_token_count,
      :last_summary_id,
      :last_summary_tokens,
      :last_model_id,
      :summarization_in_progress,
      :created_at,
      :last_active_at
    ]

    @type t :: %SessionState{
            session_id: String.t(),
            context_mode: :transparent | :declarative,
            window: [Message.t()],
            window_token_count: integer(),
            last_summary_id: integer() | nil,
            last_summary_tokens: integer(),
            last_model_id: String.t() | nil,
            summarization_in_progress: boolean(),
            created_at: DateTime.t(),
            last_active_at: DateTime.t()
          }
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(_args) do
    # Inicializar ETS para almacenar estados de sesiones
    session_table = :ets.new(:session_states, [:named_table, :protected, :set])
    {:ok, %{table: session_table}}
  end

  @doc """
  Obtiene la sesión activa o la crea si no existe.
  """
  def get_or_create_session(session_id \\ nil) do
    # Implementación del método de obtención/creación de sesión
    case :ets.lookup(:session_states, session_id) do
      [] ->
        # Si no existe en ETS, crear nueva sesión
        {:ok, new_session_id} = Storage.create_session()
        {:ok, new_session_id, %SessionState{}}
      [{_session_id, session_state}] ->
        {:ok, session_id, session_state}
    end
  end

  @doc """
  Registra un turno completo (mensaje usuario + respuesta asistente).
  """
  def append_turn(session_id, user_message, assistant_response, model_id) do
    # Actualiza ETS, persiste en PostgreSQL, y evalúa si disparar resumen eager
    
    # Guardar el mensaje del usuario
    {:ok, _user_message_id} = Storage.save_message(session_id, "user", user_message)

    # Guardar la respuesta asistente
    {:ok, _assistant_message_id} = Storage.save_message(session_id, "assistant", assistant_response, model_id: model_id)

    # Actualizar el estado en ETS
    update_session_state(session_id, :last_model_id, model_id)
    
    # Evaluar si se debe disparar resumen eager (simplificado)
    check_summarization_threshold(session_id)
    
    :ok
  end

  @doc """
  Obtiene las tres capas de contexto listas para pasar al Context.Builder.
  """
  def get_context_layers(session_id, context_spec) do
    # Consulta ETS para la ventana y el resumen; lanza búsqueda semántica si Capa 3 activa
    
    case :ets.lookup(:session_states, session_id) do
      [] -> {:error, :not_found}
      [{_session_id, session_state}] ->
        # Obtener capas del contexto desde ETS
        summary = get_summary(session_id)
        window = get_window(session_id, context_spec.window_size || 10)
        semantic = []
        
        {:ok, %{
          summary: summary,
          window: window,
          semantic: semantic
        }}
    end
  end

  @doc """
  Expira la sesión: limpia ETS pero mantiene PostgreSQL.
  """
  def expire_session(session_id) do
    # Limpia el estado en ETS pero mantiene los datos de PostgreSQL
    :ets.delete(:session_states, session_id)
    :ok
  end

  @doc """
  Fuerza recarga de sesión desde PostgreSQL.
  """
  def reload_session(session_id) do
    # Recarga desde PostgreSQL (útil tras arranque del sistema)
    case Storage.get(Session, session_id) do
      nil -> {:error, :not_found}
      session ->
        session_state = %SessionState{
          session_id: session.id,
          context_mode: session.context_mode,
          window: [],
          window_token_count: 0,
          last_summary_id: nil,
          last_summary_tokens: 0,
          last_model_id: nil,
          summarization_in_progress: false,
          created_at: session.created_at,
          last_active_at: session.last_active_at
        }
        
        :ets.insert(:session_states, {session_id, session_state})
        {:ok, session_state}
    end
  end

  # Funciones auxiliares
  defp update_session_state(session_id, field, value) do
    case :ets.lookup(:session_states, session_id) do
      [] -> :ok
      [{_session_id, session_state}] ->
        updated_state = Map.put(session_state, field, value)
        :ets.insert(:session_states, {session_id, updated_state})
    end
  end

  defp check_summarization_threshold(session_id) do
    # Verificar si se ha alcanzado el umbral para disparar resumen eager
    case :ets.lookup(:session_states, session_id) do
      [] -> :ok
      [{_session_id, session_state}] ->
        # Simplificación - en implementación real se usaría el token count
        if session_state.window_token_count > 80 do
          # Disparar SummarizationWorker en background
          :ok
        else
          :ok
        end
    end
  end

  defp get_summary(session_id) do
    # Obtener el resumen desde Storage o ETS
    case Storage.get_latest_summary(session_id) do
      {:ok, summary} -> summary.content
      _ -> nil
    end
  end

  defp get_window(session_id, limit) do
    # Obtener ventana desde Storage
    case Storage.get_window(session_id, limit) do
      {:ok, messages} -> messages
      _ -> []
    end
  end
end