defmodule ElPaso.HTTP.InternalClient do
  @moduledoc """
  Cliente interno para llamadas HTTP internas.
  """

  @doc """
  Realiza una llamada de chat interna.
  """
  def chat(_prompt, _opts) do
    # Implementación temporal
    {:ok, "response"}
  end
end
