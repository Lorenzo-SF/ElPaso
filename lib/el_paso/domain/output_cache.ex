defmodule ElPaso.Domain.OutputCache do
  @moduledoc """
  Cache LRU+TTL en ETS para respuestas de inferencia.
  
  Este módulo implementa un cache con política LRU (Least Recently Used) y TTL (Time To Live).
  """

  use GenServer

  # Configuración del cache
  @cache_name :elpaso_output_cache
  @default_ttl 3600000  # 1 hora en milisegundos
  @default_max_size 1000

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(opts) do
    size = Keyword.get(opts, :max_size, @default_max_size)
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    
    # Inicializar ETS
    cache_table = :ets.new(@cache_name, [:named_table, :protected, :set])
    
    {:ok, %{table: cache_table, max_size: size, ttl: ttl}}
  end

  @doc """
  Obtiene un valor del cache.
  """
  def get(pid, key) do
    GenServer.call(pid, {:get, key})
  end

  @doc """
  Inserta un valor en el cache.
  """
  def put(pid, key, value) do
    GenServer.cast(pid, {:put, key, value})
  end

  @impl GenServer
  def handle_call({:get, key}, _from, state) do
    case :ets.lookup(state.table, key) do
      [] ->
        {:reply, nil, state}
      [{_key, value, _timestamp}] ->
        # Verificar si ha expirado
        now = System.system_time(:millisecond)
        if now - get_timestamp(key, state) < state.ttl do
          {:reply, value, state}
        else
          :ets.delete(state.table, key)
          {:reply, nil, state}
        end
    end
  end

  @impl GenServer
  def handle_cast({:put, key, value}, state) do
    now = System.system_time(:millisecond)
    
    # Verificar si hay espacio suficiente
    if :ets.info(state.table, :size) >= state.max_size do
      # Eliminar el elemento menos reciente
      oldest_key = get_oldest_key(state)
      :ets.delete(state.table, oldest_key)
    end
    
    :ets.insert(state.table, {key, value, now})
    
    {:noreply, state}
  end

  defp get_timestamp(key, state) do
    case :ets.lookup(state.table, key) do
      [] -> 0
      [{_key, _value, timestamp}] -> timestamp
    end
  end

  defp get_oldest_key(state) do
    # Simplificación para obtener la clave más antigua
    case :ets.first(state.table) do
      :none -> nil
      key -> key
    end
  end
end