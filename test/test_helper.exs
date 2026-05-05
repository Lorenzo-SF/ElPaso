ExUnit.start()

# Configurar Sandbox para tests
{:ok, _} = ElPaso.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(ElPaso.Repo, :manual)

# Start Finch HTTP client for tests
{:ok, _} = Finch.start_link(name: ElPaso.Finch)

# Inicializar RateLimiter ETS para tests
ElPaso.Security.RateLimiter.init()

# Inicializar affinity table para tests
ElPaso.Config.Loader.init_affinity_table()
