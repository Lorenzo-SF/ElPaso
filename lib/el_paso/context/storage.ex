defmodule ElPaso.Context.Storage do
  @moduledoc """
  Módulo de almacenamiento del contexto en PostgreSQL.

  Este módulo gestiona toda la persistencia del contexto en PostgreSQL (datos de largo plazo)
  y ETS (caché de acceso rápido). Es puramente de acceso a datos: no tiene lógica de negocio.
  """

  import Ecto.Query
  alias ElPaso.Repo
  alias ElPaso.Context.Schemas.{Session, Message, RoutingDecision, ConversationSummary}
  alias ElPaso.Models.{User, ApiUsage, AutoTuneRun}

  @doc """
  Crea una nueva sesión.
  """
  @spec create_session(map()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def create_session(attrs) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Obtiene una sesión por ID.
  """
  @spec get_session(String.t()) :: Session.t() | nil
  def get_session(id) do
    Repo.get(Session, id)
  end

  @doc """
  Obtiene una sesión por user_id y profile_id.
  """
  @spec get_session_by_user_and_profile(String.t(), String.t()) :: Session.t() | nil
  def get_session_by_user_and_profile(user_id, profile_id) do
    Session
    |> where([s], s.user_id == ^user_id and s.profile_id == ^profile_id)
    |> order_by(desc: :updated_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Actualiza una sesión.
  """
  @spec update_session(Session.t(), map()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Elimina una sesión.
  """
  @spec delete_session(Session.t()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def delete_session(%Session{} = session) do
    Repo.delete(session)
  end

  @doc """
  Lista todas las sesiones para un usuario.
  """
  @spec list_sessions_by_user(String.t()) :: [Session.t()]
  def list_sessions_by_user(user_id) do
    Session
    |> where([s], s.user_id == ^user_id)
    |> order_by(desc: :updated_at)
    |> Repo.all()
  end

  @doc """
  Obtiene todos los mensajes de una sesión.
  """
  @spec get_all_messages(String.t()) :: [Message.t()]
  def get_all_messages(session_id) do
    Message
    |> where([m], m.session_id == ^session_id)
    |> order_by(asc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Crea un nuevo mensaje.
  """
  @spec create_message(map()) :: {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  def create_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Obtiene el último resumen de conversación.
  """
  @spec get_latest_summary(String.t()) :: ConversationSummary.t() | nil
  def get_latest_summary(session_id) do
    from(cs in ConversationSummary,
      where: cs.session_id == ^session_id,
      order_by: [desc: cs.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Crea un nuevo resumen de conversación.
  """
  @spec create_summary(map()) :: {:ok, ConversationSummary.t()} | {:error, Ecto.Changeset.t()}
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
  @spec query_routing_decisions(keyword()) :: [RoutingDecision.t()]
  def query_routing_decisions(opts) do
    query =
      from(r in RoutingDecision,
        order_by: [desc: r.inserted_at]
      )

    query =
      if since = Keyword.get(opts, :since) do
        since_dt = DateTime.new!(since, ~T[00:00:00])
        from(r in query, where: r.decided_at >= ^since_dt)
      else
        query
      end

    query =
      if Keyword.get(opts, :with_outcome) do
        from(r in query, where: r.outcome != "pending")
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Guardar una decisión de enrutamiento.
  """
  @spec save_routing_decision(map()) :: {:ok, RoutingDecision.t()} | {:error, Ecto.Changeset.t()}
  def save_routing_decision(attrs) do
    %RoutingDecision{}
    |> RoutingDecision.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Actualizar el resultado de un enrutamiento.
  """
  @spec update_routing_outcome(String.t(), String.t(), integer()) :: {integer(), nil | [term()]}
  def update_routing_outcome(request_id, outcome, latency_ms) do
    from(r in RoutingDecision, where: r.request_id == ^request_id)
    |> Repo.update_all(set: [outcome: outcome, latency_ms: latency_ms])
  end

  @doc """
  Guardar un auto-tune run.
  """
  @spec save_auto_tune_run(map()) :: {:ok, AutoTuneRun.t()} | {:error, Ecto.Changeset.t()}
  def save_auto_tune_run(attrs) do
    %AutoTuneRun{}
    |> AutoTuneRun.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Obtener los últimos auto-tune runs.
  """
  @spec query_auto_tune_runs(map()) :: [AutoTuneRun.t()]
  def query_auto_tune_runs(opts \\ %{}) do
    limit = Map.get(opts, :limit, 10)

    from(a in AutoTuneRun, order_by: [desc: a.inserted_at], limit: ^limit)
    |> Repo.all()
  end

  @doc """
  Obtener el último auto-tune run para hacer revert.
  """
  @spec get_last_auto_tune_run() :: AutoTuneRun.t() | nil
  def get_last_auto_tune_run do
    from(a in AutoTuneRun, order_by: [desc: a.inserted_at], limit: 1)
    |> Repo.one()
  end

  @doc """
  Obtiene el pricing de un modelo.
  """
  @spec get_model_pricing(String.t()) :: %{input: float(), output: float()} | nil
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
  @spec upsert_api_usage(map()) :: :ok | {:error, Ecto.Changeset.t()}
  def upsert_api_usage(attrs) do
    %ApiUsage{}
    |> ApiUsage.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:cost_usd, :input_tokens, :output_tokens]},
      conflict_target: [:user_id, :model_id, :date]
    )
    |> case do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Obtiene el gasto diario de un usuario.
  """
  @spec daily_spend(String.t()) :: float()
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
  @spec list_sessions() :: [Session.t()]
  def list_sessions do
    Repo.all(Session)
  end

  @doc """
  Lista todos los usuarios para admin.
  """
  @spec list_users() :: [User.t()]
  def list_users do
    Repo.all(User)
  end

  @doc """
  Genera reporte de uso para admin.
  """
  @spec usage_report(keyword()) :: %{
          users: [%{user_id: String.t(), username: String.t(), model_id: String.t(), cost: float(), input_tokens: integer(), output_tokens: integer()}],
          total_cost: float()
        }
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
        where: a.date >= ^from_date
      )

    query =
      if user_id do
        from(a in query, where: a.user_id == ^user_id)
      else
        query
      end

    query =
      if model_id do
        from(a in query, where: a.model_id == ^model_id)
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
      users:
        Enum.map(results, fn usage ->
          %{
            user_id: usage.user_id,
            username: usage.user_id,
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
  @spec usage_report_csv(keyword()) :: String.t()
  def usage_report_csv(opts) do
    report = usage_report(opts)

    "user,model,cost\n" <>
      Enum.map_join(report.users, "\n", fn user ->
        "#{user.username},#{user.model_id},#{user.cost}"
      end)
  end
end
