defmodule ElPaso.Schemas do
  @moduledoc """
  Namespace unificado para todos los schemas Ecto del proyecto.

  Este módulo re-exporta los schemas desde sus ubicaciones originales
  para facilitar la transición hacia una convención de naming consistente.

  ## Convención

  - `ElPaso.Models.*` — schemas core (Engine, Model, Personality, Profile, User)
  - `ElPaso.Context.Schemas.*` — schemas operacionales (Session, Message, RoutingDecision, etc.)

  Futuro: migrar todos los schemas bajo `ElPaso.Schemas.*`.
  """

  defmodule Model do
    alias ElPaso.Models.Model, as: Mod
    defdelegate __struct__, to: Mod
  end

  defmodule Engine do
    alias ElPaso.Models.Engine, as: Mod
    defdelegate __struct__, to: Mod
  end

  defmodule Personality do
    alias ElPaso.Models.Personality, as: Mod
    defdelegate __struct__, to: Mod
  end

  defmodule Profile do
    alias ElPaso.Models.Profile, as: Mod
    defdelegate __struct__, to: Mod
  end

  defmodule User do
    alias ElPaso.Models.User, as: Mod
    defdelegate __struct__, to: Mod
  end
end
