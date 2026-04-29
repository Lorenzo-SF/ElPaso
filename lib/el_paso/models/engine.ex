defmodule ElPaso.Models.Engine do
  @moduledoc """
  Schema para la tabla de engines (motores de inferencia).
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "engines" do
    field(:name, :string)
    field(:adapter, :string)
    field(:base_url, :string)
    field(:api_key, :string)
    field(:config, :map, default: %{})
    field(:active, :boolean, default: true)
    field(:health_status, :string, default: "unknown")
    field(:last_health_check, :utc_datetime)

    timestamps()
  end

  @doc false
  def changeset(engine, attrs) do
    engine
    |> cast(attrs, [:name, :adapter, :base_url, :api_key, :config, :active, :health_status, :last_health_check])
    |> validate_required([:name, :adapter, :base_url])
    |> unique_constraint(:name)
  end
end
