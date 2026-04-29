defmodule ElPaso.Models.Personality do
  @moduledoc """
  Schema para la tabla de personalities (personalidades/roles).
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "personalities" do
    field(:name, :string)
    field(:description, :string)
    field(:system_prompt, :string)
    field(:vector_embedding, {:array, :float})
    field(:active, :boolean, default: true)

    timestamps()
  end

  @doc false
  def changeset(personality, attrs) do
    personality
    |> cast(attrs, [:name, :description, :system_prompt, :vector_embedding, :active])
    |> validate_required([:name, :system_prompt])
    |> unique_constraint(:name)
  end
end
