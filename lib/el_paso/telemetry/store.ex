defmodule ElPaso.Telemetry.Store do
  @moduledoc """
  GenServer that subscribes to telemetry events and stores them for dashboard queries.
  """
  use GenServer

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @max_events 1000

  # Al arrancar, se suscribe a todos los eventos de ElPaso
  def init(_) do
    :telemetry.attach_many(
      "elpaso-store",
      [
        [:elpaso, :prefix, :hit],
        [:elpaso, :prefix, :miss],
        [:elpaso, :inference, :complete],
        [:elpaso, :inference, :error],
        [:elpaso, :model, :cold_start],
        [:elpaso, :router, :fallback]
      ],
      &handle_event/4,
      nil
    )

    {:ok, %{events: :queue.new(), prefix_hits: 0, prefix_misses: 0}}
  end

  @doc """
  Devuelve los N eventos más recientes.
  """
  def recent_events(n), do: GenServer.call(__MODULE__, {:recent, n})

  @doc """
  Devuelve el ratio de cache hit del prefijo.
  """
  def prefix_cache_hit_ratio(), do: GenServer.call(__MODULE__, :hit_ratio)

  @doc """
  Callback de telemetry para manejar eventos.
  """
  def handle_event(event_name, measurements, metadata, _) do
    GenServer.cast(__MODULE__, {:record, event_name, measurements, metadata})
  end

  def handle_call({:recent, n}, _from, state) do
    events =
      :queue.to_list(state.events)
      |> Enum.take(-n)
      |> Enum.map(fn {event_name, measurements, metadata} ->
        %{
          name: Enum.join(event_name, "."),
          timestamp: System.system_time(:second),
          measurements: measurements,
          metadata: metadata
        }
      end)

    {:reply, events, state}
  end

  def handle_call(:hit_ratio, _from, state) do
    total = state.prefix_hits + state.prefix_misses
    ratio = if total == 0, do: 1.0, else: state.prefix_hits / total

    {:reply, ratio, state}
  end

  def handle_cast({:record, event_name, measurements, metadata}, state) do
    new_events = :queue.in({event_name, measurements, metadata}, state.events)

    {new_hits, new_misses, trimmed_events} =
      trim_events(new_events, state.prefix_hits, state.prefix_misses)

    {:noreply, %{events: trimmed_events, prefix_hits: new_hits, prefix_misses: new_misses}}
  end

  defp trim_events(events_queue, hits, misses) do
    case :queue.len(events_queue) do
      len when len > @max_events ->
        {{:value, {event, _, _}}, rest} = :queue.out(events_queue)

        case event do
          [:elpaso, :prefix, :hit] -> {hits - 1, misses, rest}
          [:elpaso, :prefix, :miss] -> {hits, misses - 1, rest}
          _ -> {hits, misses, rest}
        end

      _ ->
        {hits, misses, events_queue}
    end
  end
end
