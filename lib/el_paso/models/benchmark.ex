defmodule ElPaso.Models.Benchmark do
  @moduledoc """
  Schema para la tabla de benchmarks (resultados de benchmarks).
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "benchmarks" do
    field(:name, :string)
    belongs_to(:model, ElPaso.Models.Model)
    belongs_to(:engine, ElPaso.Models.Engine)

    field(:prompt, :string)
    field(:latency_ms, :integer)
    field(:tokens_per_sec, :float)
    field(:quality_score, :float)
    field(:config, :map, default: %{})

    timestamps()
  end

  @doc false
  def changeset(benchmark, attrs) do
    benchmark
    |> cast(attrs, [:name, :model_id, :engine_id, :prompt, :latency_ms, :tokens_per_sec, :quality_score, :config])
    |> validate_required([:name])
  end
end
