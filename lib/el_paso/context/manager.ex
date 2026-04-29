defmodule ElPaso.Context.Manager do
  @moduledoc """
  Coordinador del ciclo de vida del contexto de sesión.

  Este módulo coordina el estado activo de las sesiones. A diferencia de Context.Storage (que solo persiste),
  el Manager mantiene el estado en memoria (ETS) para consultas rápidas.

  En modo cluster, el estado en ETS tiene TTL de 30 segundos para garantizar
  coherencia entre nodos.
  """

  use GenServer

  alias ElPaso.Config
  alias ElPaso.Context.Storage

  @cluster_ets_ttl_ms 30_000

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
      :last_active_at,
      :semantic_retrieval_enabled
    ]

    @type t :: %__MODULE__{
            session_id: String.t(),
            context_mode: String.t(),
            window: integer() | nil,
            window_token_count: integer() | nil,
            last_summary_id: String.t() | nil,
            last_summary_tokens: integer() | nil,
            last_model_id: String.t() | nil,
            summarization_in_progress: boolean() | nil,
            created_at: DateTime.t() | nil,
            last_active_at: DateTime.t() | nil,
            semantic_retrieval_enabled: boolean() | nil
          }
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(_args) do
    # Inicializar ETS para almacenar estados de sesiones
    # En modo cluster, usamos :set con tiempo de inserción para TTL
    session_table =
      :ets.new(:session_states, [
        :named_table,
        :protected,
        :set,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])

    {:ok, %{table: session_table}}
  end

  @doc """
  Obtiene la sesión activa o la crea si no existe.

  Cuando auth está habilitado, el session_id se construye como
  `user_id-uuid` para garantizar aislamiento entre usuarios.
  """
  def get_or_create_session(session_id \\ nil, user_id \\ nil) do
    # Si tenemos user_id y auth está habilitado, construir session_id con prefijo de usuario
    final_session_id = maybe_prefix_session_id(session_id, user_id)

    case get_session_state(final_session_id) do
      {:ok, session_state} ->
        {:ok, final_session_id, session_state}

      {:error, :not_found} ->
        # Si no existe en ETS ni en PostgreSQL, crear nueva sesión
        {:ok, session} = Storage.create_session(%{session_id: final_session_id, user_id: user_id})
        new_session_id = session.session_id

        session_state = %SessionState{
          session_id: new_session_id,
          context_mode: "transparent",
          created_at: DateTime.utc_now(),
          last_active_at: DateTime.utc_now()
        }

        # Guardar en ETS con timestamp
        :ets.insert(
          :session_states,
          {new_session_id, session_state, System.monotonic_time(:millisecond)}
        )

        {:ok, new_session_id, session_state}
    end
  end

  @doc """
  Obtiene el estado de sesión desde ETS con lógica de TTL en modo cluster.

  En modo cluster, si el TTL ha expirado (30 segundos),.reload_from PostgreSQL.
  """
  @spec get_session_state(String.t()) :: {:ok, SessionState.t()} | {:error, atom()}
  def get_session_state(session_id) do
    is_cluster = Config.cluster_mode?()

    case :ets.lookup(:session_states, session_id) do
      [{^session_id, session_state, inserted_at}] when is_cluster == true ->
        # Modo cluster: verificar TTL
        if System.monotonic_time(:millisecond) - inserted_at < @cluster_ets_ttl_ms do
          {:ok, session_state}
        else
          # TTL expirado: recargar desde PostgreSQL
          reload_session(session_id)
        end

      [{^session_id, session_state, _inserted_at}] ->
        {:ok, session_state}

      [] ->
        reload_session(session_id)
    end
  end

  @doc """
  Recarga una sesión desde PostgreSQL.
  """
  @spec reload_session(String.t()) :: {:ok, SessionState.t()} | {:error, atom()}
  def reload_session(session_id) do
    case Storage.get_session(session_id) do
      nil ->
        {:error, :not_found}

      session ->
        # Crear estado de sesión con datos desde PostgreSQL
        session_state = %SessionState{
          session_id: session_id,
          context_mode: session.context_mode || "transparent",
          window: 10,
          window_token_count: 2048,
          last_summary_id: nil,
          last_summary_tokens: 0,
          last_model_id: nil,
          summarization_in_progress: false,
          created_at: session.inserted_at,
          last_active_at: session.updated_at,
          semantic_retrieval_enabled: false
        }

        # Insertar en ETS con timestamp
        :ets.insert(
          :session_states,
          {session_id, session_state, System.monotonic_time(:millisecond)}
        )

        {:ok, session_state}
    end
  end

  @doc """
  Obtiene el conteo de sesiones activas.
  """
  def active_session_count do
    case :ets.info(:session_states, :size) do
      :undefined -> 0
      size -> size
    end
  end

  @doc """
  Filtra sesiones por usuario (para aislamiento).
  """
  def list_sessions_by_user(user_id) do
    pattern = {:prefix, user_id, :_}

    case :ets.match_object(:session_states, {pattern, :_}) do
      [] ->
        []

      results ->
        Enum.map(results, fn {{_prefix, _user_id, session_id}, state} ->
          {session_id, state}
        end)
    end
  end

  @doc """
  Expira la sesión: limpia ETS pero mantiene PostgreSQL.
  """
  def expire_session(session_id) do
    :ets.delete(:session_states, session_id)
    :ok
  end

  @doc """
  Actualiza el estado de una sesión en ETS (reinicia TTL en modo cluster).
  """
  @spec update_session_state(String.t(), SessionState.t()) :: :ok
  def update_session_state(session_id, session_state) do
    # Actualizar timestamp para reiniciar TTL
    :ets.insert(:session_states, {session_id, session_state, System.monotonic_time(:millisecond)})
    :ok
  end

  # Añade prefijo de user_id al session_id si auth está habilitado
  defp maybe_prefix_session_id(nil, user_id) do
    auth_enabled = Map.get(ElPaso.Config.Loader.get(), :auth, %{}) |> Map.get(:enabled, false)

    if auth_enabled and user_id do
      "#{user_id}-#{generate_uuid()}"
    else
      generate_uuid()
    end
  end

  defp maybe_prefix_session_id(session_id, user_id) do
    auth_enabled = Map.get(ElPaso.Config.Loader.get(), :auth, %{}) |> Map.get(:enabled, false)

    if auth_enabled and user_id do
      # Verificar si ya tiene prefijo
      if String.starts_with?(session_id, "#{user_id}-") do
        session_id
      else
        "#{user_id}-#{session_id}"
      end
    else
      session_id
    end
  end

  defp generate_uuid do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
