defmodule ElPaso.Repo do
  @moduledoc """
  Repository principal para ElPaso.
  Gestiona la conexión a PostgreSQL y define los esquemas.
  """

  use Ecto.Repo,
    otp_app: :elpaso,
    adapter: Ecto.Adapters.Postgres
end
