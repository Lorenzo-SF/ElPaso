defmodule ElPaso.Domain.ProfileManager do
  @moduledoc """
  Gestión de perfiles (conjuntos modelo+engine+personalidad).
  """

  alias ElPaso.Repo
  alias ElPaso.Models.Profile

  @doc """
  Crea un nuevo profile.
  """
  @spec create_profile(map()) :: {:ok, Profile.t()} | {:error, Ecto.Changeset.t()}
  def create_profile(attrs) do
    %Profile{}
    |> Profile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lista todos los profiles.
  """
  @spec list_profiles() :: [Profile.t()]
  def list_profiles do
    Repo.all(Profile)
  end

  @doc """
  Elimina un profile por nombre.
  """
  @spec delete_profile(String.t()) :: {:ok, Profile.t()} | {:error, String.t()}
  def delete_profile(name) do
    case Repo.get_by(Profile, name: name) do
      nil ->
        {:error, "Profile no encontrado"}

      profile ->
        Repo.delete(profile)
    end
  end

  @doc """
  Obtiene un profile por nombre.
  """
  @spec get_profile(String.t()) :: Profile.t() | nil
  def get_profile(name) do
    Repo.get_by(Profile, name: name)
  end
end
