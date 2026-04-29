defmodule ElPaso.Context.Schemas.RoutingDecision do
  @moduledoc """
  Schema para la tabla de decisiones de enrutamiento.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "routing_decisions" do
    belongs_to(:session, ElPaso.Context.Schemas.Session)

    field(:request_id, :string)
    field(:selected_model, :string)
    field(:runner_up, :string)
    field(:features, :map, default: %{})
    field(:scores, :map, default: %{})
    field(:reason, :string)
    field(:outcome, :string, default: "pending")
    field(:latency_ms, :integer)
    field(:decision_latency_us, :integer)

    timestamps()
  end

  @doc """
  Cambio para crear una nueva decisión de enrutamiento.
  """
  def changeset(decision, attrs) do
    decision
    |> cast(attrs, [
      :session_id,
      :request_id,
      :selected_model,
      :runner_up,
      :features,
      :scores,
      :reason,
      :outcome,
      :latency_ms,
      :decision_latency_us
    ])
    |> validate_required([:session_id, :request_id, :selected_model])
  end
end
