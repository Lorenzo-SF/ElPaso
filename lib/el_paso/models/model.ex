defmodule ElPaso.Models.Model do
  @moduledoc """
  Schema para la tabla de models (modelos de inferencia).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "models" do
    field(:name, :string)
    belongs_to(:engine, ElPaso.Models.Engine, type: :binary_id)

    field(:url, :string)
    field(:api_key, :string)
    field(:config, :map, default: %{})
    field(:active, :boolean, default: true)
    field(:max_tokens, :integer, default: 4096)
    field(:temperature, :float, default: 0.7)
    field(:top_p, :float, default: 1.0)
    field(:description, :string)

    # Routing config
    field(:task_affinity, :map, default: %{})
    field(:complexity_ceiling, :float, default: 1.0)
    field(:cold_start_estimate_ms, :integer, default: 5000)
    field(:ram_mb, :integer)
    field(:vram_mb, :integer)

    timestamps(inserted_at: :created_at)
  end

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          engine_id: integer() | nil,
          url: String.t() | nil,
          api_key: String.t() | nil,
          config: map(),
          active: boolean(),
          max_tokens: integer(),
          temperature: float(),
          top_p: float(),
          description: String.t() | nil,
          task_affinity: map(),
          complexity_ceiling: float(),
          cold_start_estimate_ms: integer(),
          ram_mb: integer() | nil,
          vram_mb: integer() | nil,
          created_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @doc false
  def changeset(model, attrs) do
    model
    |> cast(attrs, [
      :name,
      :engine_id,
      :url,
      :api_key,
      :config,
      :active,
      :max_tokens,
      :temperature,
      :top_p,
      :description,
      :task_affinity,
      :complexity_ceiling,
      :cold_start_estimate_ms,
      :ram_mb,
      :vram_mb
    ])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
