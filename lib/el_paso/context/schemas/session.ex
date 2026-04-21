defmodule ElPaso.Context.Schemas.Session do
  @moduledoc """
  Schema para la tabla de sesiones.
  """

  use Ecto.Schema

  schema "sessions" do
    field(:user_id, :string)
    field(:model_id, :string)
    field(:status, :string)
    field(:context_mode, :string)
    field(:created_at, :utc_datetime)
    field(:last_active_at, :utc_datetime)

    timestamps()
  end

  @doc """
  Cambio para crear una nueva sesión.
  """
  def changeset(session, attrs) do
    session
    |> Ecto.Changeset.cast(attrs, [:user_id, :model_id, :status, :context_mode])
    |> Ecto.Changeset.validate_required([:user_id, :model_id])
  end
end
