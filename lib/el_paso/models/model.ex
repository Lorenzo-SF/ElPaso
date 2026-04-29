defmodule ElPaso.Models.Model do
  @moduledoc """
  Schema para la tabla de models (modelos de inferencia).
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "models" do
    field(:name, :string)
    belongs_to(:engine, ElPaso.Models.Engine)

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

    timestamps()
  end

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
