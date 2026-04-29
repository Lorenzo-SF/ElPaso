defmodule ElPaso.Context.Schemas.Session do
  @moduledoc """
  Schema para la tabla de sesiones.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "sessions" do
    belongs_to(:user, ElPaso.Models.User)
    belongs_to(:profile, ElPaso.Models.Profile)

    field(:status, :string, default: "active")
    field(:context_mode, :string, default: "transparent")
    field(:token_budget, :integer, default: 32768)
    field(:current_token_count, :integer, default: 0)

    timestamps()
  end

  @doc """
  Cambio para crear una nueva sesión.
  """
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:user_id, :profile_id, :status, :context_mode, :token_budget, :current_token_count])
    |> validate_required([:user_id])
  end
end
