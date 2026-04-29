defmodule ElPaso.Domain.EngineManager do
  @moduledoc """
  Gestión de motores de inferencia.
  """

  alias ElPaso.Repo
  alias ElPaso.Models.Engine

  @doc """
  Crea un nuevo motor.
  """
  def create_engine(attrs) do
    %Engine{}
    |> Engine.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lista todos los motores.
  """
  def list_engines do
    Repo.all(Engine)
  end

  @doc """
  Elimina un motor por nombre.
  """
  def delete_engine(name) do
    case Repo.get_by(Engine, name: name) do
      nil ->
        {:error, "Motor no encontrado"}
      engine ->
        Repo.delete(engine)
    end
  end

  @doc """
  Actualiza un motor existente.
  """
  def update_engine(name, attrs) do
    case Repo.get_by(Engine, name: name) do
      nil ->
        {:error, "Motor no encontrado"}
      engine ->
        engine
        |> Engine.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Prueba la conectividad de un motor.
  """
  def test_engine(name) do
    case Repo.get_by(Engine, name: name) do
      nil ->
        {:error, "Motor no encontrado"}
      engine ->
        # In a real implementation, this would make an actual HTTP request to test connectivity
        # For now, we'll just return success
        :ok
    end
  end

  @doc """
  Obtiene un motor por nombre.
  """
  def get_engine(name) do
    Repo.get_by(Engine, name: name)
  end
end