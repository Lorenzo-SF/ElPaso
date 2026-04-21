defmodule ElPaso.Domain.ModelManager do
  @moduledoc """
  Supervisor para la gestión de modelos del sistema.
  """

  use Supervisor

  @impl Supervisor
  def init(_args) do
    children = [
      # Aquí se pueden añadir procesos de gestión de modelos
    ]

    opts = [strategy: :one_for_one, name: ElPaso.Domain.ModelManager]
    Supervisor.init(children, opts)
  end

  @doc """
  Realiza inferencia usando un modelo específico.
  """
  def infer(_model_id, _request) do
    # Implementación temporal
    {:ok, "response"}
  end

  @doc """
  Devuelve el estado de todos los modelos.
  """
  def all_states do
    []
  end

  @doc """
  Registra el resultado de una llamada al modelo.
  """
  def record_call_result(_request_id, _latency_ms, _outcome) do
    :ok
  end
end
