defmodule ElPaso.Context.Schemas.Message do
  @moduledoc """
  Schema para la tabla de mensajes.
  """

  use Ecto.Schema

  schema "messages" do
    field(:session_id, :string)
    field(:role, :string)
    field(:content, :string)
    field(:model_id, :string)
    field(:token_estimate, :integer)
    field(:embedding, Pgvector.Ecto.Vector)
    field(:created_at, :utc_datetime)
    field(:sequence_number, :integer)

    timestamps()
  end

  @doc """
  Cambio para crear un nuevo mensaje.
  """
  def changeset(message, attrs) do
    message
    |> Ecto.Changeset.cast(attrs, [
      :session_id,
      :role,
      :content,
      :model_id,
      :token_estimate,
      :embedding
    ])
    |> Ecto.Changeset.validate_required([:session_id, :role, :content])
  end
end
