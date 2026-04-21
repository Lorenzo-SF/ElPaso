defmodule ElPaso.Context.Session do
  @moduledoc """
  Estructura de datos para el contexto de sesión.
  
  Esta estructura representa el estado completo de una sesión de conversación.
  """

  defstruct [
    :id,
    :created_at,
    :last_active_at,
    :context_mode,
    :window,
    :window_token_count,
    :last_summary_id,
    :last_summary_tokens,
    :last_model_id,
    :summarization_in_progress,
    :metadata
  ]

  @type t :: %ElPaso.Context.Session{
          id: String.t(),
          created_at: DateTime.t(),
          last_active_at: DateTime.t(),
          context_mode: :transparent | :declarative,
          window: [map()],
          window_token_count: integer(),
          last_summary_id: integer() | nil,
          last_summary_tokens: integer(),
          last_model_id: String.t() | nil,
          summarization_in_progress: boolean(),
          metadata: map()
        }
end