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

# ── V4.0: Task Categories ────────────────────────────────────────────
# Las categorías de tarea son usadas por el Router (capa 1 del DecisionEngine)
# para clasificar peticiones por tipo: code, reasoning, translation, etc.
# El mapa de keywords tiene pesos (1-5) que se suman al encontrar matches.
# Los defaults están en ElPaso.Domain.Router.TaskCategories.@default_categories.
# Para añadir tus propias categorías, sobreescribe esta key:
#
# config :elpaso, :task_categories,
#   ElPaso.Domain.Router.TaskCategories.categories()
#   |> Map.put(:mi_categoria, %{keywords: %{"keyword" => 5, "otra" => 3}})
#
# o define completamente tus categorías. Si no se especifica, se usan los defaults.

import_config "#{config_env()}.exs"
