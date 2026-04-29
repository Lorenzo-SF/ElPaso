defmodule ElPaso.Models.Engine do
  @moduledoc """
  Schema para la tabla de engines (motores de inferencia).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "engines" do
    field(:name, :string)
    field(:adapter, :string)
    field(:base_url, :string)
    field(:api_key, :string)
    field(:config, :map, default: %{})
    field(:active, :boolean, default: true)
    field(:health_status, :string, default: "unknown")
    field(:last_health_check, :utc_datetime)

    timestamps(inserted_at: :created_at)
  end

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          adapter: String.t(),
          base_url: String.t(),
          api_key: String.t() | nil,
          config: map(),
          active: boolean(),
          health_status: String.t(),
          last_health_check: DateTime.t() | nil,
          created_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @doc false
  def changeset(engine, attrs) do
    engine
    |> cast(attrs, [
      :name,
      :adapter,
      :base_url,
      :api_key,
      :config,
      :active,
      :health_status,
      :last_health_check
    ])
    |> validate_required([:name, :adapter, :base_url])
    |> unique_constraint(:name)
  end
end
