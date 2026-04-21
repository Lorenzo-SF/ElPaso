defmodule ElPaso.Domain.Types.RouterStatsReport do
  @moduledoc """
  Estructura para reporte de estadísticas del router.
  """

  defstruct period: :last_hour,
            total_decisions: 0,
            fallback_count: 0,
            fallback_rate_pct: 0.0,
            cold_starts: 0,
            error_count: 0,
            by_model: %{},
            by_task_type: %{},
            generated_at: nil
end
