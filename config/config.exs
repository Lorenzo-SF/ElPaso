import Config

# Configura el logger (default: info, se sobreescribe por entorno)
config :logger, :console, format: "$time [$level] $message\n"

# Configuración de Ecto
config :elpaso, ecto_repos: [ElPaso.Repo]

# Finch HTTP client pools para inference
config :finch,
  pools: [
    {:default, [size: 50, connect_timeout: 30_000]},
    {ElPaso.Finch, [size: 50, connect_timeout: 30_000, timeout: 120_000]}
  ]

# Configuración de la aplicación
# WARNING: All model configurations should be done via database, not config.exs.
# ElPaso does not include any pre-configured models or engines.
# Use CLI commands to register models and engines.

import_config "#{config_env()}.exs"
