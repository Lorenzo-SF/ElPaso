defmodule ElPaso.Context.Schemas.ConversationSummary do
  @moduledoc """
  Schema para la tabla de resúmenes de conversaciones.
  """

  use Ecto.Schema

  schema "conversation_summaries" do
    field :session_id, :string
    field :summary, :string
    field :created_at, :utc_datetime

    timestamps()
  end

  @doc """
  Cambio para crear un nuevo resumen.
  """
  def changeset(summary, attrs) do
    summary
    |> Ecto.Changeset.cast(attrs, [:session_id, :summary])
    |> Ecto.Changeset.validate_required([:session_id, :summary])
  end
end