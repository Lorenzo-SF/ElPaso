defmodule ElPaso.Context.Schemas.Session do
  @moduledoc """
  Schema para la tabla de sesiones (InitialSetup).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:session_id, :string, autogenerate: false}
  schema "sessions" do
    field(:user_id, :string)
    field(:model_id, :string)
    field(:context_mode, :string, default: "transparent")
    field(:status, :string, default: "active")

    timestamps()
  end

  @doc """
  Cambio para crear una nueva sesión.
  """
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :session_id,
      :user_id,
      :model_id,
      :context_mode,
      :status
    ])
  end
end
