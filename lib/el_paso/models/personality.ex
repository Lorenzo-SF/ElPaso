defmodule ElPaso.Models.Personality do
  @moduledoc """
  Schema para personalidades (roles/skills) que determinan qué modelo y engine
  usar para cada tipo de solicitud.

  Cada personalidad es un "experto" en el MoE manual de ElPaso:
    - Define system_prompt (el prompt de sistema)
    - Apunta a un model + engine concretos
    - Tiene triggers (keywords, task_types, detection_rules) para activarse
    - Tiene prioridad y una puede ser default (fallback)
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "personalities" do
    field(:name, :string)
    field(:description, :string)
    field(:system_prompt, :string)
    field(:active, :boolean, default: true)

    # Routing
    field(:trigger_keywords, {:array, :string}, default: [])
    field(:trigger_task_types, {:array, :string}, default: [])
    field(:detection_rules, :map, default: %{})
    field(:priority, :integer, default: 0)
    field(:is_default, :boolean, default: false)

    # Config overrides para el modelo
    field(:config, :map, default: %{})

    # Relaciones
    belongs_to(:model, ElPaso.Models.Model)
    belongs_to(:engine, ElPaso.Models.Engine)

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(personality, attrs) do
    personality
    |> cast(attrs, [
      :name, :description, :system_prompt, :active,
      :trigger_keywords, :trigger_task_types, :detection_rules,
      :priority, :is_default, :config, :model_id, :engine_id
    ])
    |> validate_required([:name, :system_prompt])
    |> unique_constraint(:name)
    |> validate_default_uniqueness()
  end

  defp validate_default_uniqueness(changeset) do
    if get_change(changeset, :is_default) == true do
      unique_constraint(changeset, :is_default,
        name: :one_default_personality,
        message: "solo puede haber una personalidad por defecto"
      )
    else
      changeset
    end
  end
end
