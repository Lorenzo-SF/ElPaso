defmodule ElPaso.Domain.PersonalityLoadManager do
  @moduledoc """
  Gestor de carga de personalidades en paralelo con sistema de prioridades.

  ## Propósito

  Controla CUÁNTAS personalidades (modelos) pueden estar cargadas simultáneamente
  y decide CUÁL desalojar cuando se necesita espacio para una nueva, basándose en:
    - `max_parallel`: máximo de personalidades cargadas a la vez (configurable)
    - `priority`: a mayor prioridad, más difícil de desalojar
    - `protected`: personalidades protegidas que NUNCA pueden ser desalojadas

  ## Prioridad del DecisionEngine

  La personalidad `classifier-router` (modelo `[classifier]` usado por la capa 3
  del DecisionEngine) DEBE tener prioridad máxima (999) y estar protegida.
  Esto garantiza que el motor de decisiones NUNCA se quede sin su modelo
  clasificador, incluso bajo presión de carga.

  ## Configuración

      config :elpaso, :personality_load,
        max_parallel: 2,
        warmup_on_start: true,
        protected_personalities: ["classifier-router"]

  ## Uso

      # Antes de una inferencia, solicitar carga:
      case PersonalityLoadManager.request_load(personality) do
        {:ok, :already_loaded} -> :ok
        {:ok, :loaded} -> :ok
        {:ok, :loaded, evicted: old_name} -> Logger.info("Evicted \#{old_name}")
        {:error, reason} -> {:error, reason}
      end
  """

  use GenServer
  require Logger

  alias ElPaso.Domain.PersonalityManager

  @default_max_parallel 1

  # ── Estructura de estado ──────────────────────────────────────────────────

  defstruct max_parallel: @default_max_parallel,
            loaded: %{},
            protected: MapSet.new(),
            eviction_count: 0,
            total_loads: 0

  @type entry :: %{
          priority: integer(),
          model_name: String.t(),
          loaded_at: DateTime.t(),
          personality_name: String.t()
        }

  @type state :: %__MODULE__{
          max_parallel: pos_integer(),
          loaded: %{String.t() => entry()},
          protected: MapSet.t(String.t()),
          eviction_count: non_neg_integer(),
          total_loads: non_neg_integer()
        }

  # ── Client API ────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Solicita cargar una personalidad. Si ya está cargada, devuelve
  `{:ok, :already_loaded}`. Si hay espacio, la carga. Si no hay espacio,
  intenta desalojar la de menor prioridad (no protegida).

  Devuelve:
    - `{:ok, :already_loaded}` — ya estaba cargada
    - `{:ok, :loaded}` — cargada exitosamente (había espacio)
    - `{:ok, :loaded, evicted: old_name}` — cargada tras desalojar a `old_name`
    - `{:error, :at_capacity_lower_priority}` — no se pudo cargar (prioridad insuficiente)
    - `{:error, :cannot_evict_protected}` — todos los cargados están protegidos
  """
  @spec request_load(map()) ::
          {:ok, :already_loaded | :loaded}
          | {:ok, :loaded, evicted: String.t()}
          | {:error, atom()}
  def request_load(personality) when is_map(personality) do
    GenServer.call(__MODULE__, {:request_load, personality}, 15_000)
  end

  @spec request_load(String.t()) ::
          {:ok, :already_loaded | :loaded}
          | {:ok, :loaded, evicted: String.t()}
          | {:error, atom()}
  def request_load(personality_name) when is_binary(personality_name) do
    case PersonalityManager.get_personality(personality_name) do
      nil -> {:error, :personality_not_found}
      personality -> request_load(personality)
    end
  end

  @doc """
  Libera una personalidad (la marca como no cargada).
  No detiene el modelo — solo actualiza el tracking interno.
  """
  @spec release(String.t()) :: :ok
  def release(personality_name) when is_binary(personality_name) do
    GenServer.cast(__MODULE__, {:release, personality_name})
  end

  @doc """
  Protege una personalidad para que NUNCA pueda ser desalojada.
  Usar para el `classifier-router` del DecisionEngine.
  """
  @spec protect(String.t()) :: :ok
  def protect(personality_name) when is_binary(personality_name) do
    GenServer.cast(__MODULE__, {:protect, personality_name})
  end

  @doc "Elimina la protección de una personalidad."
  @spec unprotect(String.t()) :: :ok
  def unprotect(personality_name) when is_binary(personality_name) do
    GenServer.cast(__MODULE__, {:unprotect, personality_name})
  end

  @doc """
  Estado actual de carga:
    - `:loaded` → lista de personalidades cargadas con prioridad
    - `:max_parallel` → máximo configurado
    - `:protected` → personalidades protegidas
    - `:available_slots` → huecos libres
    - `:eviction_count` → total de desalojos realizados
    - `:total_loads` → total de cargas realizadas
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Precarga las personalidades de mayor prioridad hasta llenar los slots.
  Útil tras el arranque para tener modelos listos.
  """
  @spec warmup() :: :ok
  def warmup do
    GenServer.cast(__MODULE__, :warmup)
  end

  # ── Server Callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    max_parallel = Keyword.get(opts, :max_parallel) ||
                     Application.get_env(:elpaso, :personality_load, [])
                     |> Keyword.get(:max_parallel, @default_max_parallel)

    protected_names = Keyword.get(opts, :protected) ||
                        Application.get_env(:elpaso, :personality_load, [])
                        |> Keyword.get(:protected_personalities, [])

    # Auto-proteger el classifier-router si existe y no está ya protegido
    protected = MapSet.new(protected_names)

    Logger.info("[PersonalityLoadManager] Inicializado. max_parallel=#{max_parallel}, protected=#{inspect(MapSet.to_list(protected))}")

    {:ok,
     %__MODULE__{
       max_parallel: max_parallel,
       loaded: %{},
       protected: protected,
       eviction_count: 0,
       total_loads: 0
     }}
  end

  @impl true
  def handle_call({:request_load, personality}, _from, state) do
    name = personality.name
    priority = personality.priority || 0
    model_name = get_model_name(personality)

    # Caso 1: ya está cargada
    if Map.has_key?(state.loaded, name) do
      {:reply, {:ok, :already_loaded}, state}
    else
      free_slots = state.max_parallel - map_size(state.loaded)

      # Caso 2: hay espacio libre
      if free_slots > 0 do
        entry = build_entry(name, priority, model_name)
        new_state = %{state | loaded: Map.put(state.loaded, name, entry), total_loads: state.total_loads + 1}
        Logger.info("[PersonalityLoadManager] Cargada '#{name}' (prio:#{priority}, modelo:#{model_name}). #{free_slots - 1} slot(s) libre(s).")
        {:reply, {:ok, :loaded}, new_state}
      else
        # Caso 3: sin espacio — intentar desalojar
        case find_eviction_candidate(state.loaded, state.protected) do
          nil ->
            # No hay candidato — todos están protegidos o tienen más prioridad
            Logger.warning("[PersonalityLoadManager] No se pudo cargar '#{name}': todos los slots ocupados por personalidades protegidas o de mayor prioridad.")
            {:reply, {:error, :cannot_evict_protected}, state}

          {victim_name, victim_entry} ->
            # ¿Merece la pena desalojar? Solo si la nueva tiene MAYOR prioridad
            if priority > victim_entry.priority do
              new_loaded =
                state.loaded
                |> Map.delete(victim_name)
                |> Map.put(name, build_entry(name, priority, model_name))

              new_state = %{
                state
                | loaded: new_loaded,
                  eviction_count: state.eviction_count + 1,
                  total_loads: state.total_loads + 1
              }

              Logger.info("[PersonalityLoadManager] Desalojada '#{victim_name}' (prio:#{victim_entry.priority}) → cargada '#{name}' (prio:#{priority}, modelo:#{model_name}). Eviction ##{new_state.eviction_count}")

              {:reply, {:ok, :loaded, evicted: victim_name}, new_state}
            else
              Logger.info("[PersonalityLoadManager] '#{name}' (prio:#{priority}) no supera a '#{victim_name}' (prio:#{victim_entry.priority}) — rechazada.")
              {:reply, {:error, :at_capacity_lower_priority}, state}
            end
        end
      end
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    loaded_entries =
      state.loaded
      |> Enum.map(fn {name, entry} ->
        %{
          personality: name,
          priority: entry.priority,
          model: entry.model_name,
          loaded_at: entry.loaded_at,
          protected: MapSet.member?(state.protected, name)
        }
      end)
      |> Enum.sort_by(& &1.priority, :desc)

    status = %{
      loaded: loaded_entries,
      max_parallel: state.max_parallel,
      protected: MapSet.to_list(state.protected),
      available_slots: state.max_parallel - map_size(state.loaded),
      eviction_count: state.eviction_count,
      total_loads: state.total_loads
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:release, name}, state) do
    if Map.has_key?(state.loaded, name) do
      Logger.info("[PersonalityLoadManager] Liberada '#{name}'")
      {:noreply, %{state | loaded: Map.delete(state.loaded, name)}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:protect, name}, state) do
    Logger.info("[PersonalityLoadManager] Protegida '#{name}' — no podrá ser desalojada.")
    {:noreply, %{state | protected: MapSet.put(state.protected, name)}}
  end

  @impl true
  def handle_cast({:unprotect, name}, state) do
    Logger.info("[PersonalityLoadManager] Desprotegida '#{name}'.")
    {:noreply, %{state | protected: MapSet.delete(state.protected, name)}}
  end

  @impl true
  def handle_cast(:warmup, state) do
    if state.max_parallel == 0 do
      Logger.info("[PersonalityLoadManager] Warmup omitido: max_parallel=0")
      {:noreply, state}
    else
      personalities = PersonalityManager.list_active()
      free = state.max_parallel - map_size(state.loaded)

      if free <= 0 do
        {:noreply, state}
      else
        # Cargar las de mayor prioridad que no estén ya cargadas
        to_warm =
          personalities
          |> Enum.reject(fn p -> Map.has_key?(state.loaded, p.name) end)
          |> Enum.sort_by(& &1.priority, :desc)
          |> Enum.take(free)

        new_loaded =
          Enum.reduce(to_warm, state.loaded, fn p, acc ->
            entry = build_entry(p.name, p.priority || 0, get_model_name(p))
            Map.put(acc, p.name, entry)
          end)

        warmed_names = Enum.map(to_warm, & &1.name)
        Logger.info("[PersonalityLoadManager] Warmup: precargadas #{length(warmed_names)}: #{inspect(warmed_names)}")

        {:noreply, %{state | loaded: new_loaded, total_loads: state.total_loads + length(to_warm)}}
      end
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  defp build_entry(name, priority, model_name) do
    %{
      personality_name: name,
      priority: priority,
      model_name: model_name,
      loaded_at: DateTime.utc_now()
    }
  end

  defp get_model_name(personality) do
    case personality do
      %{model: %{name: model_name}} -> model_name
      %{model_id: _} ->
        case Ecto.assoc_loaded?(personality.model) do
          true -> personality.model.name
          false -> "unknown"
        end
      _ -> "unknown"
    end
  end

  @doc """
  Encuentra la personalidad cargada de MENOR prioridad que NO esté protegida.
  Devuelve `{name, entry}` o `nil` si todas están protegidas.
  """
  @spec find_eviction_candidate(map(), MapSet.t()) :: {String.t(), map()} | nil
  def find_eviction_candidate(loaded, protected) do
    loaded
    |> Enum.reject(fn {name, _entry} -> MapSet.member?(protected, name) end)
    |> Enum.min_by(fn {_name, entry} -> entry.priority end, fn -> nil end)
  end
end
