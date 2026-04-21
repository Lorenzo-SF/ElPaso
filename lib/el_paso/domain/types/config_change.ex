defmodule ElPaso.Domain.Types.ConfigChange do
  @moduledoc """
  Estructura que representa un cambio en la configuración.
  """

  defstruct [
    :path,
    :type,
    :old_value,
    :new_value,
    :impact
  ]

  @type t :: %ConfigChange{
          path: String.t(),
          type: :added | :removed | :changed,
          old_value: any(),
          new_value: any(),
          impact: :hot_reload | :requires_model_restart | :requires_full_restart
        }
end
