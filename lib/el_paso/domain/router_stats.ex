defmodule ElPaso.Domain.RouterStats do
  @moduledoc """
  Módulo para la gestión de estadísticas del router.
  """

  defstruct total_decisions: 0,
            fallback_count: 0,
            fallback_rate_pct: 0.0,
            by_task_type: %{},
            by_model: %{},
            cold_starts: 0,
            error_count: 0

  @doc """
  Agrega estadísticas de router.
  """
  def aggregate(_since) do
    %__MODULE__{}
  end
end
