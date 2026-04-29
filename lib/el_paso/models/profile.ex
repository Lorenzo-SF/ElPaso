defmodule ElPaso.Models.Profile do
  @moduledoc """
  Schema para la tabla de profiles (conjuntos modelo+engine+personalidad).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "profiles" do
    field(:name, :string)
    belongs_to(:model, ElPaso.Models.Model)

    belongs_to(:engine, ElPaso.Models.Engine)

    belongs_to(:personality, ElPaso.Models.Personality)

    field(:config, :map, default: %{})
    field(:active, :boolean, default: true)
    field(:description, :string)

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:name, :model_id, :engine_id, :personality_id, :config, :active, :description])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
