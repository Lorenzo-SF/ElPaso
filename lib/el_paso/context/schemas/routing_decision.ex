defmodule ElPaso.Context.Schemas.RoutingDecision do
  @moduledoc """
  Schema para la tabla de decisiones de enrutamiento.
  """

  use Ecto.Schema

  schema "routing_decisions" do
    field :session_id, :string
    field :model_id, :string
    field :decision, :string
    field :created_at, :utc_datetime

    timestamps()
  end

  @doc """
  Cambio para crear una nueva decisión de enrutamiento.
  """
  def changeset(decision, attrs) do
    decision
    |> Ecto.Changeset.cast(attrs, [:session_id, :model_id, :decision])
    |> Ecto.Changeset.validate_required([:session_id, :model_id, :decision])
  end
end