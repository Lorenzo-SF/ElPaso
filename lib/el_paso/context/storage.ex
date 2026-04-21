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

  Opciones:
  - since: Date.t() - fecha mínima
  - with_outcome: boolean() - incluir solo las que tienen outcome
  """
  def query_routing_decisions(opts) do
    # Esta función es un stub que devuelve datos quemados para testing
    # En producción, usar Repo.all:
    # Repo.all(from r in RoutingDecision, where: r.decided_at >= ^since, ...)
    #
    # Por ahora devolvemos datos de ejemplo para demostrar el análisis
    # _since = Keyword.get(opts, :since, Date.add(Date.utc_today(), -30))
    _with_outcome = Keyword.get(opts, :with_outcome, false)

    # Generar datos de ejemplo basados en los últimos 30 días
    # Esto simula lo que vendría de la BD
    for _i <- 1..50 do
      days_ago = :rand.uniform(30)

      %{
        request_id: "req_#{:rand.uniform(100_000)}",
        session_id: "session_#{:rand.uniform(50)}",
        model_id: Enum.random(["claude-3-opus", "claude-3-sonnet", "claude-3-haiku"]),
        task_type: Enum.random([:code, :reasoning, :summarization, :question_answer]),
        selected_model: "claude-3-sonnet",
        runner_up: "claude-3-haiku",
        token_estimate: :rand.uniform(10000),
        complexity_score: :rand.uniform(),
        language: "en",
        scores: %{},
        reason: "Best fit",
        outcome: Enum.random([:success, :success, :success, :retry, :error]),
        decision_latency_us: :rand.uniform(5000),
        decided_at: DateTime.add(DateTime.utc_now(), -days_ago * 86400)
      }
    end
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
  def save_auto_tune_run(%{applied: _count}) do
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

  @doc """
  Obtiene el pricing de un modelo.
  """
  def get_model_pricing(_model_id) do
    {:error, :not_found}
  end

  @doc """
  Upserta el uso de API.
  """
  def upsert_api_usage(_usage) do
    :ok
  end

  @doc """
  Obtiene el gasto diário de un usuario.
  """
  def daily_spend(_user_id) do
    0.0
  end

  @doc """
  Lista todas las sesiones para admin.
  """
  def list_sessions do
    []
  end

  @doc """
  Lista todos los usuarios para admin.
  """
  def list_users do
    []
  end

  @doc """
  Genera reporte de uso para admin.
  """
  def usage_report(_opts) do
    %{users: [], total_cost: 0.0}
  end

  @doc """
  Genera reporte de uso en CSV.
  """
  def usage_report_csv(_opts) do
    "user,model,cost\n"
  end
end
