defmodule ElPaso.Models.AutoTuneRun do
  @moduledoc """
  Schema para la tabla de auto_tune_runs (InitialSetup).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "auto_tune_runs" do
    field(:applied, :integer)
    field(:changes, :map)

    timestamps()
  end

  @doc false
  def changeset(auto_tune_run, attrs) do
    auto_tune_run
    |> cast(attrs, [:applied, :changes])
  end
end
