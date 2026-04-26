defmodule ElPaso.Domain.ModelManager do
  @moduledoc """
  Gestión de modelos y motores de inferencia.
  """

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @impl GenServer
  def init(_opts) do
    {:ok, %{}}
  end

  def all_states do
    []
  end

  def infer(_model_id, _request) do
    {:error, :not_implemented}
  end

  def record_call_result(_request_id, _latency_ms, _outcome) do
    :ok
  end

  def load_models do
    # For now just return empty list - will be implemented later
    []
  end

  def models do
    load_models()
  end
end
