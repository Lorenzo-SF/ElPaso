defmodule ElPaso.Context.Schemas.ConversationSummary do
  @moduledoc """
  Schema para la tabla de resúmenes de conversaciones (InitialSetup).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "conversation_summaries" do
    field(:session_id, :string)
    field(:summary, :string)
    field(:summary_tokens, :integer)
    field(:window_start, :utc_datetime)
    field(:window_end, :utc_datetime)

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Cambio para crear un nuevo resumen.
  """
  def changeset(summary, attrs) do
    summary
    |> cast(attrs, [
      :session_id,
      :summary,
      :summary_tokens,
      :window_start,
      :window_end
    ])
    |> validate_required([:session_id, :summary])
  end
end
