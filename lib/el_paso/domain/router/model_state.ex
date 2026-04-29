defmodule ElPaso.Domain.Router.ModelState do
  @moduledoc """
  Estado de un modelo para el router.
  """

  defstruct [
    :model_id,
    :status,
    :current_queue_depth,
    :avg_latency_ms,
    :last_error_at,
    :consecutive_errors,
    :ram_mb,
    :node,
    :routing_config
  ]

  @type t :: %__MODULE__{
          model_id: String.t(),
          status: :hot | :cold | :disabled,
          current_queue_depth: integer(),
          avg_latency_ms: float(),
          last_error_at: DateTime.t() | nil,
          consecutive_errors: integer(),
          ram_mb: integer(),
          node: String.t() | nil,
          routing_config: %{
            task_affinity: map(),
            complexity_ceiling: integer() | nil,
            cold_start_estimate_ms: integer() | nil
          }
        }
end
