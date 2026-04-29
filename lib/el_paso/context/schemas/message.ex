defmodule ElPaso.Context.Schemas.Message do
  @moduledoc """
  Schema para la tabla de mensajes.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    belongs_to(:session, ElPaso.Context.Schemas.Session)

    field(:role, :string)
    field(:content, :string)
    field(:model_id, :string)
    field(:token_estimate, :integer, default: 0)
    field(:vector_embedding, {:array, :float})
    field(:sequence_number, :integer)

    timestamps()
  end

  @doc """
  Cambio para crear un nuevo mensaje.
  """
  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :session_id,
      :role,
      :content,
      :model_id,
      :token_estimate,
      :vector_embedding,
      :sequence_number
    ])
    |> validate_required([:session_id, :role, :content, :sequence_number])
  end
end
