defmodule ElPaso.Telemetry.PrometheusExporter do
  def metrics do
    [
      %{
        name: "elpaso.inference.complete.total",
        type: :counter,
        tags: [:model_id, :task_type],
        description: "Total de inferencias completadas"
      },
      %{
        name: "elpaso.inference.complete.latency_ms",
        type: :distribution,
        event_name: [:elpaso, :inference, :complete],
        measurement: :latency_ms,
        tags: [:model_id],
        buckets: [100, 500, 1000, 2000, 5000, 10000],
        description: "Latencia de inferencia en ms"
      },
      %{
        name: "elpaso.model.status",
        type: :last_value,
        event_name: [:elpaso, :model, :health_check],
        measurement: fn _measurements, metadata ->
          case metadata.status do
            :hot -> 1
            :warming -> 0.5
            _ -> 0
          end
        end,
        tags: [:model_id],
        description: "Estado del modelo (1=hot, 0.5=warming, 0=cold/error)"
      },
      %{
        name: "elpaso.router.fallback.total",
        type: :counter,
        tags: [:reason],
        description: "Total de fallbacks del router"
      },
      %{
        name: "elpaso.prefix.cache_hit_ratio",
        type: :last_value,
        event_name: [:elpaso, :prefix, :hit_ratio_updated],
        measurement: :ratio,
        description: "Ratio actual de cache hit del prefijo"
      },
      %{
        name: "elpaso.model.cold_start.startup_duration_ms",
        type: :distribution,
        event_name: [:elpaso, :model, :cold_start],
        measurement: :startup_duration_ms,
        tags: [:model_id],
        buckets: [1000, 5000, 10000, 30000, 60000],
        description: "Duración de arranque desde frío"
      }
    ]
  end
end
