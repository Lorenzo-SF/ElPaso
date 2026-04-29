defmodule ElPaso.Domain.PersonalityManager do
  @moduledoc """
  Gestión de personalidades/roles para modelos.
  """

  alias ElPaso.Repo
  alias ElPaso.Models.Personality

  @doc """
  Crea una nueva personalidad.
  """
  def create_personality(attrs) do
    %Personality{}
    |> Personality.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lista todas las personalidades.
  """
  def list_personalities do
    Repo.all(Personality)
  end

  @doc """
  Obtiene una personalidad por nombre.
  """
  def get_personality(name) do
    Repo.get_by(Personality, name: name)
  end

  @doc """
  Elimina una personalidad por nombre.
  """
  def delete_personality(name) do
    case Repo.get_by(Personality, name: name) do
      nil ->
        {:error, "Personalidad no encontrada"}

      personality ->
        Repo.delete(personality)
    end
  end

  @doc """
  Actualiza una personalidad existente.
  """
  def update_personality(name, attrs) do
    case Repo.get_by(Personality, name: name) do
      nil ->
        {:error, "Personalidad no encontrada"}

      personality ->
        personality
        |> Personality.changeset(attrs)
        |> Repo.update()
    end
  end
end
