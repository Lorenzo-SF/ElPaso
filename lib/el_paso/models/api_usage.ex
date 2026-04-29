defmodule ElPaso.Models.ApiUsage do
  @moduledoc """
  Schema para la tabla de api_usage (uso de API y costes).
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "api_usage" do
    belongs_to(:user, ElPaso.Models.User)

    field(:model_id, :string)
    field(:date, :date)
    field(:input_tokens, :integer, default: 0)
    field(:output_tokens, :integer, default: 0)
    field(:cost_usd, :decimal, default: 0.00)

    timestamps()
  end

  @doc false
  def changeset(api_usage, attrs) do
    api_usage
    |> cast(attrs, [:user_id, :model_id, :date, :input_tokens, :output_tokens, :cost_usd])
    |> validate_required([:model_id, :date])
  end
end
