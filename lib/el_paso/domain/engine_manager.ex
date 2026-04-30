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
  Prueba la conectividad de un motor haciendo un HTTP GET a su base_url.

  Retorna:
  - `{:ok, latency_ms}` si el motor responde
  - `{:error, reason}` si no se puede conectar
  """
  def test_engine(name) do
    case Repo.get_by(Engine, name: name) do
      nil ->
        {:error, "Motor no encontrado"}

      %Engine{base_url: base_url, adapter: adapter} ->
        start = System.monotonic_time()

        # Determinar endpoint de health check según el adapter
        health_url = health_url(adapter, base_url)

        case :httpc.request(:get, {health_url, []}, [], []) do
          {:ok, {{_version, status, _reason}, _headers, _body}}
          when status >= 200 and status < 400 ->
            latency_ms =
              System.convert_time_unit(System.monotonic_time() - start, :native, :millisecond)

            {:ok, latency_ms}

          {:ok, {{_version, status, _reason}, _headers, _body}} ->
            {:error, "HTTP #{status}"}

          {:error, reason} ->
            {:error, inspect(reason)}
        end
    end
  end

  # Ollama responde a GET /api/tags
  defp health_url("ollama", base_url), do: "#{base_url}/api/tags"
  # Para otros adapters intentamos el raíz o /v1/models
  defp health_url(_adapter, base_url) do
    # Strip trailing slash
    base = :string.trim(base_url, :trailing, "/")
    "#{base}/v1/models"
  end

  @doc """
  Obtiene un motor por nombre.
  """
  def get_engine(name) do
    Repo.get_by(Engine, name: name)
  end
end
