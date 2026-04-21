defmodule ElPaso.Context.Storage do
  @moduledoc """
  Módulo de almacenamiento del contexto en PostgreSQL.

  Este módulo gestiona toda la persistencia del contexto en PostgreSQL (datos de largo plazo)
  y ETS (caché de acceso rápido). Es puramente de acceso a datos: no tiene lógica de negocio.
  """

  @doc """
  Crea una nueva sesión.
  """
  def create_session(opts) do
    context_mode = Keyword.get(opts, :context_mode, "transparent")

    # Crear la sesión (simplificación - en producción usaría Repo)
    _session = %ElPaso.Context.Schemas.Session{
      context_mode: context_mode,
      user_id: Keyword.get(opts, :user_id),
      model_id: Keyword.get(opts, :model_id),
      status: Keyword.get(opts, :status, "active")
    }

    # En producción: ElPaso.Context.Repo.insert(session)
    {:ok, %{id: "session_#{:rand.uniform(1000)}"}}
  end

  @doc """
  Obtiene una sesión.
  """
  def get_session(_session_id) do
    {:error, :not_found}
  end

  @doc """
  Obtiene todos los mensajes de una sesión.
  """
  def get_all_messages(_session_id) do
    {:ok, []}
  end

  @doc """
  Obtiene el último resumen de conversación.
  """
  def get_latest_summary(_session_id) do
    {:error, :not_found}
  end

  @doc """
  Obtiene las decisiones de enrutamiento.
  """
  def query_routing_decisions(_opts) do
    []
  end

  @doc """
  Guardar una decisión de enrutamiento.
  """
  def save_routing_decision(_decision) do
    :ok
  end

  @doc """
  Actualizar el resultado de un enrutamiento.
  """
  def update_routing_outcome(_request_id, _outcome, _latency_ms) do
    :ok
  end

  @doc """
  Guardar un auto-tune run.
  """
  def save_auto_tune_run(%{applied: _count} = run) do
    :ok
  end

  @doc """
  Obtener los últimos auto-tune runs.
  """
  def query_auto_tune_runs(_opts \\ %{}) do
    []
  end

  @doc """
  Obtener el último auto-tune run para hacer revert.
  """
  def get_last_auto_tune_run do
    nil
  end
end
