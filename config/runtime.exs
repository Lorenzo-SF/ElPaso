import Config

# ──────────────────────────────────────────────────────────────
# Configuración en tiempo de ejecución (runtime.exs)
#
# Este archivo se ejecuta al iniciar la aplicación.
# Las configuraciones aquí tienen prioridad sobre config.exs
# y los archivos de entorno (dev.exs, prod.exs, test.exs).
#
# SOLO configuraciones dinámicas que dependen del entorno de
# despliegue. NO hardcodear modelos, engines, o defaults inseguros.
# ──────────────────────────────────────────────────────────────

# Puerto HTTP (si no se configuró en el archivo de entorno)
if config_env() in [:dev, :prod] do
  config :elpaso,
    http_port: String.to_integer(System.get_env("ELPASO_PORT") || "4000")
end

# Repositorio Ecto — conexión desde variables de entorno
if config_env() in [:dev, :prod] do
  config :elpaso, ElPaso.Repo,
    hostname: System.get_env("DB_HOST", "localhost"),
    username: System.get_env("DB_USER", "postgres"),
    password: System.get_env("DB_PASSWORD", "postgres"),
    database: System.get_env("DB_NAME", "elpaso_#{config_env()}"),
    port: String.to_integer(System.get_env("DB_PORT", "5432")),
    pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "10")),
    log: config_env() == :dev
end
