defmodule ElPaso.Context.Schemas.ConversationSummary do
  @moduledoc """
  Schema para la tabla de resúmenes de conversaciones.
  """

  use Ecto.Schema

  schema "conversation_summaries" do
    field(:session_id, :string)
    field(:content, :string)
    field(:covers_until_message_id, :string)
    field(:token_estimate, :integer)
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
    |> Ecto.Changeset.cast(attrs, [
      :session_id,
      :content,
      :covers_until_message_id,
      :token_estimate,
      :generated_by_model
    ])
    |> Ecto.Changeset.validate_required([:session_id, :content])
  end
end
