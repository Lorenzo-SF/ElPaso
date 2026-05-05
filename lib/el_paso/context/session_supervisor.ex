defmodule ElPaso.Context.SessionSupervisor do
  @moduledoc """
  DynamicSupervisor para SessionContext GenServers.

  Cada sesión tiene su propio GenServer que mantiene el estado compartido.
  Se crean bajo demanda y se terminan tras inactividad.
  """

  use DynamicSupervisor

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc "Asegura que existe un SessionContext para la sesión dada."
  @spec ensure_session(String.t()) :: :ok | {:error, term()}
  def ensure_session(session_id) do
    case Registry.lookup(ElPaso.SessionRegistry, session_id) do
      [{_pid, _}] ->
        :ok

      [] ->
        case DynamicSupervisor.start_child(__MODULE__, %{
               id: {ElPaso.Context.SessionContext, session_id},
               start: {ElPaso.Context.SessionContext, :start_link, [[session_id: session_id]]},
               restart: :temporary
             }) do
          {:ok, _pid} -> :ok
          {:ok, _pid, _info} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
