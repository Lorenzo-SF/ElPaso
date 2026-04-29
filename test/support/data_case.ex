defmodule ElPaso.DataCase do
  @moduledoc """
  Módulo base para tests que requieren acceso a la base de datos.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias ElPaso.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(ElPaso.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(ElPaso.Repo, {:shared, self()})
    end

    :ok
  end
end
