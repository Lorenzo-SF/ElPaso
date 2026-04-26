defmodule ElPaso.Models.Model do
  @moduledoc """
  Esquema para modelos de inferencia.
  """

  defstruct [
    :id,
    :name,
    :description,
    :engine_id,
    :url,
    :api_key,
    :active,
    :max_tokens,
    :created_at,
    :updated_at
  ]

  def create(attrs) do
    {:ok, %ElPaso.Models.Model{}}
  end

  def all do
    []
  end
end
