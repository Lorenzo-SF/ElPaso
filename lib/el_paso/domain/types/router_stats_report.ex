defmodule ElPaso.Domain.Types.RouterStatsReport do
  @moduledoc """
  Estructura que representa un reporte de estadísticas de routing.
  """

  defstruct [
    :period,
    :total_decisions,
    :fallback_count,
    :fallback_rate_pct,
    :by_task_type,
    :by_model,
    :cold_starts,
    :error_count,
    :generated_at
  ]

  @type t :: %RouterStatsReport{
          period: atom() | tuple(),
          total_decisions: integer(),
          fallback_count: integer(),
          fallback_rate_pct: float(),
          by_task_type: %{atom() => %{total: integer(), by_model: map()}},
          by_model: %{
            String.t() => %{
              total_calls: integer(),
              success_rate_pct: float(),
              avg_latency_ms: integer(),
              p95_latency_ms: integer(),
              error_count: integer()
            }
          },
          cold_starts: integer(),
          error_count: integer(),
          generated_at: DateTime.t()
        }
end
