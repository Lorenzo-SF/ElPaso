defmodule ElPaso.Context.Storage do
  @moduledoc """
  Módulo de almacenamiento del contexto en PostgreSQL.

  Este módulo gestiona toda la persistencia del contexto en PostgreSQL (datos de largo plazo)
  y ETS (caché de acceso rápido). Es puramente de acceso a datos: no tiene lógica de negocio.
  """

  alias ElPaso.Repo
  alias ElPaso.Context.Schemas.{Session, Message, RoutingDecision, ConversationSummary}
  alias ElPaso.Models.{User, ApiUsage, Benchmark, AutoTuneRun}

  @doc """
  Crea una nueva sesión.
  """
  def create_session(attrs) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Obtiene una sesión por ID.
  """
  def get_session(id) do
    Repo.get(Session, id)
  end

  @doc """
  Obtiene una sesión por user_id y profile_id.
  """
  def get_session_by_user_and_profile(user_id, profile_id) do
    Session
    |> where(user_id: ^user_id, profile_id: ^profile_id)
    |> order_by(desc: :updated_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Actualiza una sesión.
  """
  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Elimina una sesión.
  """
  def delete_session(%Session{} = session) do
    Repo.delete(session)
  end

  @doc """
  Lista todas las sesiones para un usuario.
  """
  def list_sessions_by_user(user_id) do
    Session
    |> where(user_id: ^user_id)
    |> order_by(desc: :updated_at)
    |> Repo.all()
  end

  @doc """
  Obtiene todos los mensajes de una sesión.
  """
  def get_all_messages(session_id) do
    Message
    |> where(session_id: ^session_id)
    |> order_by(asc: :sequence_number)
    |> Repo.all()
  end

  @doc """
  Crea un nuevo mensaje.
  """
  def create_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Obtiene el último resumen de conversación.
  """
  def get_latest_summary(session_id) do
    from(cs in ConversationSummary,
      where: cs.session_id == ^session_id,
      order_by: [desc: cs.generated_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Crea un nuevo resumen de conversación.
  """
  def create_summary(attrs) do
    %ConversationSummary{}
    |> ConversationSummary.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Obtiene las decisiones de enrutamiento.

  Opciones:
  - since: Date.t() - fecha mínima
  - with_outcome: boolean() - incluir solo las que tienen outcome
  """
  def query_routing_decisions(opts) do
    query =
      from(r in RoutingDecision,
        order_by: [desc: r.created_at]
      )

    query =
      if since = Keyword.get(opts, :since) do
        from(r in query, where: r.created_at >= ^since)
      else
        query
      end

    query =
      if with_outcome = Keyword.get(opts, :with_outcome) do
        from(r in query, where: r.outcome != "pending")
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Guardar una decisión de enrutamiento.
  """
  def save_routing_decision(attrs) do
    %RoutingDecision{}
    |> RoutingDecision.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Actualizar el resultado de un enrutamiento.
  """
  def update_routing_outcome(request_id, outcome, latency_ms) do
    from(r in RoutingDecision, where: r.request_id == ^request_id)
    |> Repo.update_all(set: [outcome: outcome, latency_ms: latency_ms])
  end

  @doc """
  Guardar un auto-tune run.
  """
  def save_auto_tune_run(attrs) do
    %AutoTuneRun{}
    |> AutoTuneRun.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Obtener los últimos auto-tune runs.
  """
  def query_auto_tune_runs(opts \\ %{}) do
    limit = Map.get(opts, :limit, 10)

    from(a in AutoTuneRun, order_by: [desc: a.created_at], limit: ^limit)
    |> Repo.all()
  end

  @doc """
  Obtener el último auto-tune run para hacer revert.
  """
  def get_last_auto_tune_run do
    from(a in AutoTuneRun, order_by: [desc: a.created_at], limit: 1)
    |> Repo.one()
  end

  @doc """
  Obtiene el pricing de un modelo.
  """
  def get_model_pricing(model_id) do
    # Default pricing for common models
    case model_id do
      "claude-3-opus" -> %{input: 0.015, output: 0.075}
      "claude-3-sonnet" -> %{input: 0.003, output: 0.015}
      "claude-3-haiku" -> %{input: 0.00025, output: 0.00125}
      _ -> nil
    end
  end

  @doc """
  Upserta el uso de API.
  """
  def upsert_api_usage(attrs) do
    %ApiUsage{}
    |> ApiUsage.changeset(attrs)
    |> Repo.insert(on_conflict: [:cost_usd], conflict_target: [:user_id, :model_id, :date],
      replace: [:cost_usd, :input_tokens, :output_tokens])
  end

  @doc """
  Obtiene el gasto diario de un usuario.
  """
  def daily_spend(user_id) do
    today = Date.utc_today()

    from(a in ApiUsage,
      where: a.user_id == ^user_id and a.date == ^today,
      select: sum(a.cost_usd)
    )
    |> Repo.one()
    |> case do
      nil -> 0.0
      value -> Decimal.to_float(value)
    end
  end

  @doc """
  Lista todas las sesiones para admin.
  """
  def list_sessions do
    Repo.all(Session)
  end

  @doc """
  Lista todos los usuarios para admin.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Genera reporte de uso para admin.
  """
  def usage_report(opts) do
    user_id = Keyword.get(opts, :user_id)
    model_id = Keyword.get(opts, :model_id)
    period = Keyword.get(opts, :period, "30d")

    # Parse period to days
    days =
      case period do
        "7d" -> 7
        "30d" -> 30
        "90d" -> 90
        _ -> 30
      end

    from_date = Date.utc_today() |> Date.add(-days)

    query =
      from(a in ApiUsage,
        where: a.date >= ^from_date,
        join: u in User,
        on: a.user_id == u.id,
        preload: [:user]
      )

    query =
      if user_id do
        from(q in query, where: q.user_id == ^user_id)
      else
        query
      end

    query =
      if model_id do
        from(q in query, where: q.model_id == ^model_id)
      else
        query
      end

    results = Repo.all(query)

    total_cost =
      results
      |> Enum.reduce(0.0, fn usage, acc ->
        acc + Decimal.to_float(usage.cost_usd)
      end)

    %{
      users: Enum.map(results, fn usage ->
        %{
          user_id: usage.user_id,
          username: usage.user.username,
          model_id: usage.model_id,
          cost: Decimal.to_float(usage.cost_usd),
          input_tokens: usage.input_tokens,
          output_tokens: usage.output_tokens
        }
      end),
      total_cost: total_cost
    }
  end

  @doc """
  Genera reporte de uso en CSV.
  """
  def usage_report_csv(opts) do
    report = usage_report(opts)

    "user,model,cost\n" <>
      Enum.map_join(report.users, "\n", fn user ->
        "#{user.username},#{user.model_id},#{user.cost}"
      end)
  end
end
