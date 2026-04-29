defmodule ElPaso.Context.Schemas.Message do
  @moduledoc """
  Schema para la tabla de mensajes (InitialSetup).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "messages" do
    field(:session_id, :string)
    field(:role, :string)
    field(:content, :string)
    field(:model_id, :string)
    field(:tokens, :integer)

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
      :tokens
    ])
    |> validate_required([:session_id, :role, :content])
  end
end
