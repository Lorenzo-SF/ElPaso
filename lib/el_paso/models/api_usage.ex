defmodule ElPaso.Models.ApiUsage do
  @moduledoc """
  Schema para la tabla de api_usage (InitialSetup).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "api_usage" do
    field(:user_id, :string)
    field(:model_id, :string)
    field(:date, :date)
    field(:input_tokens, :integer, default: 0)
    field(:output_tokens, :integer, default: 0)
    field(:cost_usd, :decimal)
    field(:request_count, :integer, default: 0)

    timestamps()
  end

  @doc false
  def changeset(api_usage, attrs) do
    api_usage
    |> cast(attrs, [
      :user_id,
      :model_id,
      :date,
      :input_tokens,
      :output_tokens,
      :cost_usd,
      :request_count
    ])
    |> validate_required([:user_id, :model_id, :date])
  end
end
