defmodule ElPaso.Domain.ModelManager do
  @moduledoc """
  Gestión de modelos y motores de inferencia con Circuit Breaker (Zaguan).

  Cada modelo tiene su propio circuit breaker para proteger contra fallos
  en cascada. Los circuit breakers se crean lazily bajo
  `Zaguan.Engine.CircuitBreaker.Registry`.
  """

  use GenServer
  require Logger
  alias ElPaso.Repo
  alias ElPaso.Models.{Model, Engine}
  alias ElPaso.Engine.Adapter

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

  `request` es un mapa con:
    - `:messages` — lista de mensajes [{role, content}]
    - `:model_hint` — hint opcional de modelo

  La inferencia se ejecuta de forma asíncrona en un Task supervisado.
  El proceso llamante recibe la respuesta vía mensaje o se bloquea
  con un timeout configurable (default: 120_000 ms).
  """
  def infer(model_id, request, timeout \\ 120_000) do
    # Validación síncrona rápida: ¿existe el modelo?
    case get_model_from_state(model_id) do
      nil ->
        {:error, :model_not_found}

      model ->
        # Ejecutar inferencia en un Task separado para no bloquear el GenServer
        task =
          Task.Supervisor.async_nolink(ElPaso.TaskSupervisor, fn ->
            ensure_circuit_breaker(model_id)

            case Zaguan.Engine.CircuitBreaker.call(
                   model_id,
                   fn -> do_infer(model, request) end,
                   @circuit_opts
                 ) do
              {:ok, response} ->
                Zaguan.Engine.CircuitBreaker.success(model_id)
                {:ok, response}

              {:error, reason} ->
                Zaguan.Engine.CircuitBreaker.failure(model_id)
                Logger.warning("[ModelManager] Inference failed for #{model_id}")
                {:error, reason}
            end
          end)

        case Task.yield(task, timeout) || Task.shutdown(task) do
          {:ok, result} -> result
          nil -> {:error, %{type: :timeout, message: "Inference timed out after #{timeout}ms"}}
        end
    end
  end

  @impl GenServer
  def handle_call(:all_states, _from, state) do
    {:reply, Enum.map(state.models, &model_to_state/1), state}
  end

  @impl GenServer
  def handle_call({:get_model, model_id}, _from, state) do
    model = Enum.find(state.models, &(&1.name == model_id))
    {:reply, model, state}
  end

  @impl GenServer
  def handle_call(:reload_models, _from, _state) do
    models = load_models()
    {:reply, {:ok, length(models)}, %{models: models, engine_states: %{}}}
  end

  # Internal: actual HTTP inference via Engine.Adapter
  defp do_infer(%Model{} = model, request) do
    # Load engine
    engine =
      case model.engine_id do
        nil -> nil
        _ -> Repo.get(Engine, model.engine_id)
      end

    case engine do
      nil ->
        {:error, %{type: :no_engine, message: "Model has no engine configured"}}

      %Engine{active: false} ->
        {:error, %{type: :engine_inactive, message: "Engine #{engine.name} is inactive"}}

      %Engine{} = engine ->
        # Extract messages from request (兼容 con formato {messages: [...]})
        messages = extract_messages(request)

        case Adapter.infer(messages, model, engine, %{}) do
          {:ok, response} ->
            {:ok, response}

          {:error, reason} ->
            Logger.error("[ModelManager] Adapter error: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  # Extract messages from various request formats
  defp extract_messages(%{messages: messages}) when is_list(messages), do: messages
  defp extract_messages(%{"messages" => messages}) when is_list(messages), do: messages

  defp extract_messages(%{content: content}) when is_binary(content),
    do: [%{"role" => "user", "content" => content}]

  defp extract_messages(other) when is_map(other), do: Map.get(other, :messages, [])

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

  @impl GenServer
  def handle_info({:model_updated, _model_id}, state) do
    # Recargar modelos cuando se notifica un cambio
    models = load_models()
    {:noreply, %{state | models: models}}
  end

  # ── Helpers ─────────────────────────────────────────────────

  defp get_model_from_state(model_id) do
    GenServer.call(__MODULE__, {:get_model, model_id})
  end

  def reload_models do
    GenServer.call(__MODULE__, :reload_models)
  end

  # ── Server Callbacks ────────────────────────────────────────
  # Lazy-starts it if not already running under Zaguan.Engine.CircuitBreaker.Registry.
  defp ensure_circuit_breaker(model_name) do
    case Registry.lookup(Zaguan.Engine.CircuitBreaker.Registry, model_name) do
      [{_pid, _}] ->
        :ok

      [] ->
        {:ok, _pid} =
          Zaguan.Engine.CircuitBreaker.start_link(name: model_name, threshold: 5, timeout: 60_000)
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
