defmodule ElPaso.Models.Engine do
  @moduledoc """
  Esquema para motores de inferencia.
  """

  defstruct [
    :id,
    :name,
    :description,
    :adapter,
    :base_url,
    :api_key,
    :active,
    :created_at,
    :updated_at
  ]

  def create(attrs) do
    {:ok, %ElPaso.Models.Engine{}}
  end

  def all do
    []
  end
end
