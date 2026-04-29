defmodule ElPaso.Domain.ProfileManager do
  @moduledoc """
  Gestión de perfiles (conjuntos modelo+engine+personalidad).
  """

  alias ElPaso.Repo
  alias ElPaso.Models.Profile

  @doc """
  Crea un nuevo profile.
  """
  def create_profile(attrs) do
    %Profile{}
    |> Profile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lista todos los profiles.
  """
  def list_profiles do
    Repo.all(Profile)
  end

  @doc """
  Elimina un profile por nombre.
  """
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
  def get_profile(name) do
    Repo.get_by(Profile, name: name)
  end
end
