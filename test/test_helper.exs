ExUnit.start()

# Iniciar el Repo para tests
{:ok, _} = ElPaso.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(ElPaso.Repo, :auto)
