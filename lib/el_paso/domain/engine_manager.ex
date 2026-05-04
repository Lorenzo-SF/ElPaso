defmodule ElPaso.Domain.EngineManager do
  @moduledoc """
  Gestión de motores de inferencia.
  """

  alias ElPaso.Repo
  alias ElPaso.Models.Engine

  @doc """
  Crea un nuevo motor.
  """
  @spec create_engine(map()) :: {:ok, Engine.t()} | {:error, Ecto.Changeset.t()}
  def create_engine(attrs) do
    %Engine{}
    |> Engine.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lista todos los motores.
  """
  @spec list_engines() :: [Engine.t()]
  def list_engines do
    Repo.all(Engine)
  end

  @doc """
  Elimina un motor por nombre.
  """
  @spec delete_engine(String.t()) :: {:ok, Engine.t()} | {:error, String.t()}
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
  @spec update_engine(String.t(), map()) :: {:ok, Engine.t()} | {:error, Ecto.Changeset.t() | String.t()}
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
  @spec test_engine(String.t()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def test_engine(name) do
    case Repo.get_by(Engine, name: name) do
      nil ->
        {:error, "Motor no encontrado"}

      %Engine{base_url: base_url, adapter: adapter} ->
        start = System.monotonic_time()
        health_url = health_url(adapter, base_url)

        # Usar Finch en lugar de :httpc (bloqueante)
        request = Finch.build(:get, health_url)
        timeout = 10_000  # Timeout corto para health check

        case Finch.request(request, ElPaso.Finch, receive_timeout: timeout) do
          {:ok, %{status: status}} when status >= 200 and status < 400 ->
            latency_ms =
              System.convert_time_unit(System.monotonic_time() - start, :native, :millisecond)
            {:ok, latency_ms}

          {:ok, %{status: status}} ->
            {:error, "HTTP #{status}"}

          {:error, reason} ->
            {:error, inspect(reason)}
        end
    end
  end

  # Health check URLs por adapter
  defp health_url("ollama", base_url), do: "#{String.trim_trailing(base_url, "/")}/api/tags"
  defp health_url("openai", base_url), do: "#{String.trim_trailing(base_url, "/")}/models"
  defp health_url("anthropic", base_url), do: "#{String.trim_trailing(base_url, "/")}/v1/messages"
  defp health_url(_adapter, base_url) do
    # Para llama.cpp y compatibles: intentar /v1/models o /health
    "#{String.trim_trailing(base_url, "/")}/health"
  end

  @doc """
  Obtiene un motor por nombre.
  """
  @spec get_engine(String.t()) :: Engine.t() | nil
  def get_engine(name) do
    Repo.get_by(Engine, name: name)
  end
end
