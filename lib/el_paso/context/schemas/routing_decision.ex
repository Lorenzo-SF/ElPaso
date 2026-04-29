defmodule ElPaso.Context.Schemas.RoutingDecision do
  @moduledoc """
  Schema para la tabla de decisiones de enrutamiento (InitialSetup).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "routing_decisions" do
    field(:request_id, :string)
    field(:session_id, :string)
    field(:model_id, :string)
    field(:task_type, :string)
    field(:selected_model, :string)
    field(:runner_up, :string)
    field(:token_estimate, :integer)
    field(:complexity_score, :float)
    field(:language, :string)
    field(:scores, :map)
    field(:reason, :string)
    field(:outcome, :string)
    field(:latency_ms, :integer)
    field(:decision_latency_us, :integer)
    field(:decided_at, :utc_datetime)

    timestamps()
  end

  @doc """
  Cambio para crear una nueva decisión de enrutamiento.
  """
  def changeset(decision, attrs) do
    decision
    |> cast(attrs, [
      :request_id,
      :session_id,
      :model_id,
      :task_type,
      :selected_model,
      :runner_up,
      :token_estimate,
      :complexity_score,
      :language,
      :scores,
      :reason,
      :outcome,
      :latency_ms,
      :decision_latency_us,
      :decided_at
    ])
    |> validate_required([:request_id, :session_id, :model_id, :task_type, :selected_model])
  end
end
