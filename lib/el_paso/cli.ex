defmodule ElPaso.CLI do
  @moduledoc """
  Main CLI entry point for ElPaso.

  iter-049: `main/1` now delegates to `ElPaso.CLI.Definition.main/1`
  (alaja DSL).  The legacy hand-rolled dispatcher is preserved in
  `ElPaso.CLI.Legacy` for backwards compatibility with internal
  tests and edge cases.

  See `lib/el_paso/cli/definition.ex` for the DSL declaration.
  """

  alias ElPaso.CLI.Definition

  @doc """
  Main entry point. Delegates to `ElPaso.CLI.Definition.main/1` (alaja DSL).
  """
  def main(args) do
    Definition.main(args)
  end

  defdelegate legacy_dispatch(args), to: __MODULE__.Legacy, as: :legacy_dispatch
end
