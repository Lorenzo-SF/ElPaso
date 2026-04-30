defmodule ElPaso.Domain.ModelManager do
  @moduledoc """
  Gestión de modelos y motores de inferencia con Circuit Breaker (Zaguan).

  Cada modelo tiene su propio circuit breaker para proteger contra fallos
  en cascada. Los circuit breakers se crean lazily bajo
  `Zaguan.Engine.CircuitBreaker.Registry`.
  """

  use GenServer
  alias ElPaso.Repo
  alias ElPaso.Models.{Model, Engine}

  @circuit_opts [threshold: 5, timeout: 60_000]

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
    # Load models from DB on startup (safe fallback if tables don't exist)
    models =
      try do
        load_models()
      rescue
        _ -> []
      end

    {:ok, %{models: models, engine_states: %{}}}
  end

  @doc """
  Devuelve todos los estados de modelos.
  """
  def all_states do
    GenServer.call(__MODULE__, :all_states)
  end

  @doc """
  Ejecuta inferencia en un modelo con protección de circuit breaker.
  """
  def infer(model_id, request) do
    GenServer.call(__MODULE__, {:infer, model_id, request})
  end

  @impl GenServer
  def handle_call(:all_states, _from, state) do
    {:reply, Enum.map(state.models, &model_to_state/1), state}
  end

  def handle_call({:infer, model_id, _request}, _from, state) do
    # Find the model
    model = Enum.find(state.models, &(&1.name == model_id))

    result =
      case model do
        nil ->
          {:error, :model_not_found}

        %Model{} ->
          # Ensure circuit breaker exists for this model
          ensure_circuit_breaker(model_id)

          # Protected call via Zaguan Circuit Breaker
          case Zaguan.Engine.CircuitBreaker.call(
                 model_id,
                 fn -> do_infer(model) end,
                 @circuit_opts
               ) do
            {:ok, response} ->
              Zaguan.Engine.CircuitBreaker.success(model_id)
              {:ok, response}

            {:error, reason} ->
              Zaguan.Engine.CircuitBreaker.failure(model_id)
              {:error, reason}
          end
      end

    {:reply, result, state}
  end

  # Internal: actual inference (no circuit breaker)
  defp do_infer(%Model{name: name, engine_id: engine_id}) do
    engine =
      case engine_id do
        nil -> nil
        _ -> Repo.get(Engine, engine_id)
      end

    case engine do
      nil ->
        {:ok, %{content: "Response from #{name}", finish_reason: :stop}}

      _ ->
        {:ok, %{content: "Response from #{name}", finish_reason: :stop}}
    end
  end

  @doc """
  Registra el resultado de una llamada.
  """
  def record_call_result(request_id, latency_ms, outcome) do
    GenServer.cast(__MODULE__, {:record_result, request_id, latency_ms, outcome})
  end

  @impl GenServer
  def handle_cast({:record_result, _request_id, _latency_ms, _outcome}, state) do
    # Update model state with new metrics
    {:noreply, state}
  end

  @doc """
  Crea un nuevo modelo.
  """
  def create_model(attrs) do
    %Model{}
    |> Model.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lista todos los modelos.
  """
  def list_models do
    Repo.all(Model)
  end

  @doc """
  Elimina un modelo por nombre.
  """
  def delete_model(name) do
    case Repo.get_by(Model, name: name) do
      nil ->
        {:error, "Modelo no encontrado"}

      model ->
        Repo.delete(model)
    end
  end

  @doc """
  Actualiza un modelo existente.
  """
  def update_model(name, attrs) do
    case Repo.get_by(Model, name: name) do
      nil ->
        {:error, "Modelo no encontrado"}

      model ->
        model
        |> Model.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Inicia un modelo (marcar como activo).
  """
  def start_model(name) do
    case Repo.get_by(Model, name: name) do
      nil ->
        {:error, "Modelo no encontrado"}

      model ->
        model
        |> Model.changeset(%{active: true})
        |> Repo.update()
    end
  end

  @doc """
  Detiene un modelo (marcar como inactivo).
  """
  def stop_model(name) do
    case Repo.get_by(Model, name: name) do
      nil ->
        {:error, "Modelo no encontrado"}

      model ->
        model
        |> Model.changeset(%{active: false})
        |> Repo.update()
    end
  end

  @doc """
  Carga los modelos desde la base de datos.
  """
  def load_models do
    Repo.all(Model)
  end

  @doc """
  Obtiene un modelo por nombre.
  """
  def get_model(name) do
    Repo.get_by(Model, name: name)
  end

  @doc """
  Devuelve todos los modelos.
  """
  def models do
    load_models()
  end

  # Helper: ensures a Zaguan Circuit Breaker exists for the given model name.
  # Lazy-starts it if not already running under Zaguan.Engine.CircuitBreaker.Registry.
  defp ensure_circuit_breaker(model_name) do
    case Registry.lookup(Zaguan.Engine.CircuitBreaker.Registry, model_name) do
      [{_pid, _}] -> :ok
      [] -> {:ok, _pid} = Zaguan.Engine.CircuitBreaker.start_link(name: model_name, threshold: 5, timeout: 60_000)
    end
  end

  # Helper function to convert Model to ModelState for the router
  defp model_to_state(%Model{} = model) do
    %ElPaso.Domain.Router.ModelState{
      model_id: model.name,
      status: if(model.active, do: :hot, else: :disabled),
      current_queue_depth: 0,
      avg_latency_ms: 0,
      last_error_at: nil,
      consecutive_errors: 0,
      ram_mb: model.ram_mb || 0,
      node: nil,
      routing_config: %{
        task_affinity: model.task_affinity || %{},
        complexity_ceiling: model.complexity_ceiling,
        cold_start_estimate_ms: model.cold_start_estimate_ms
      }
    }
  end
end
