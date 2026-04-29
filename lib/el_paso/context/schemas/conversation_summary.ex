defmodule ElPaso.Context.Schemas.ConversationSummary do
  @moduledoc """
  Schema para la tabla de resúmenes de conversaciones.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "conversation_summaries" do
    belongs_to(:session, ElPaso.Context.Schemas.Session)

    field(:content, :string)
    field(:covers_until_message_id, :string)
    field(:token_estimate, :integer, default: 0)
    field(:generated_by_model, :string)
    field(:generated_at, :utc_datetime)
    field(:archived_at, :utc_datetime)

    timestamps()
  end

  @doc """
  Cambio para crear un nuevo resumen.
  """
  def changeset(summary, attrs) do
    summary
    |> cast(attrs, [
      :session_id, :content, :covers_until_message_id, :token_estimate,
      :generated_by_model, :generated_at, :archived_at
    ])
    |> validate_required([:session_id, :content])
  end
end
