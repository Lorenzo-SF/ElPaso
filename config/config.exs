import Config

# Configura el logger (default: info, se sobreescribe por entorno)
config :logger, :console,
  format: "$time [$level] $message\n"

# Configuración de Ecto
config :elpaso, ecto_repos: [ElPaso.Repo]

# Configuración de la aplicación
# WARNING: All model configurations should be done via database, not config.exs.
# ElPaso does not include any pre-configured models or engines.
# Use CLI commands to register models and engines.

import_config "#{config_env()}.exs"
