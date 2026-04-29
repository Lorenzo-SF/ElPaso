defmodule ElPaso.Models.AutoTuneRun do
  @moduledoc """
  Schema para la tabla de auto_tune_runs (registros de auto-tune).
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "auto_tune_runs" do
    field(:applied, :integer, default: 0)
    field(:changes, :map, default: %{})

    timestamps()
  end

  @doc false
  def changeset(auto_tune_run, attrs) do
    auto_tune_run
    |> cast(attrs, [:applied, :changes])
  end
end
