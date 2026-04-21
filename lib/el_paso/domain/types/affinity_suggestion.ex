defmodule ElPaso.Domain.Types.AffinitySuggestion do
  @moduledoc """
  Estructura que representa una sugerencia de ajuste de afinidad.
  """

  defstruct [
    :model_id,
    :task_type,
    :current_affinity,
    :suggested_affinity,
    :delta,
    :confidence,
    :based_on_n_decisions,
    :reason
  ]

  @type t :: %AffinitySuggestion{
          model_id: String.t(),
          task_type: atom(),
          current_affinity: float(),
          suggested_affinity: float(),
          delta: float(),
          # 0.0-1.0
          confidence: float(),
          based_on_n_decisions: integer(),
          reason: String.t()
        }
end
