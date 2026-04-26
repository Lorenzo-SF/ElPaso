defmodule ElPaso.Models do
  @moduledoc """
  Módulo de delegación para operaciones en modelos y motores.
  """

  def all_models do
    []
  end

  def create_model(_attrs) do
    {:error, :not_implemented}
  end

  def all_engines do
    []
  end

  def create_engine(_attrs) do
    {:error, :not_implemented}
  end
end
