defmodule ElPaso.Models.User do
  @moduledoc """
  Schema para la tabla de users (usuarios del sistema).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field(:username, :string)
    field(:api_key_hash, :string)
    field(:role, :string, default: "user")
    field(:budget_daily, :decimal, default: 100.00)
    field(:active, :boolean, default: true)

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :api_key_hash, :role, :budget_daily, :active])
    |> validate_required([:username, :role])
    |> unique_constraint(:username)
  end
end
