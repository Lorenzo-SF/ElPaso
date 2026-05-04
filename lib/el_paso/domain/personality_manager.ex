defmodule ElPaso.Domain.PersonalityManager do
  @moduledoc """
  Gestión de personalidades/roles para modelos.
  """

  alias ElPaso.Repo
  alias ElPaso.Models.Personality

  @doc """
  Crea una nueva personalidad.
  """
  @spec create_personality(map()) :: {:ok, Personality.t()} | {:error, Ecto.Changeset.t()}
  def create_personality(attrs) do
    %Personality{}
    |> Personality.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lista todas las personalidades.
  """
  @spec list_personalities() :: [Personality.t()]
  def list_personalities do
    Repo.all(Personality)
  end

  @doc """
  Obtiene una personalidad por nombre.
  """
  @spec get_personality(String.t()) :: Personality.t() | nil
  def get_personality(name) do
    Repo.get_by(Personality, name: name)
  end

  @doc """
  Elimina una personalidad por nombre.
  """
  @spec delete_personality(String.t()) :: {:ok, Personality.t()} | {:error, String.t()}
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
  @spec update_personality(String.t(), map()) :: {:ok, Personality.t()} | {:error, Ecto.Changeset.t() | String.t()}
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
