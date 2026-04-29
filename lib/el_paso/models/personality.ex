defmodule ElPaso.Models.Personality do
  @moduledoc """
  Schema para la tabla de personalities (personalidades/roles).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "personalities" do
    field(:name, :string)
    field(:description, :string)
    field(:system_prompt, :string)
    field(:active, :boolean, default: true)

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(personality, attrs) do
    personality
    |> cast(attrs, [:name, :description, :system_prompt, :active])
    |> validate_required([:name, :system_prompt])
    |> unique_constraint(:name)
  end
end
