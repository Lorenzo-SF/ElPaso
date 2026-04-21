import Config

# Configuración para entorno de producción
config :elpaso,
  http_port: 4000,
  inference_server_url: "http://localhost:8081/v1",
  inference_api_key: "sk-local"

# Configuración de la base de datos para producción
config :elpaso, ElPaso.Repo,
  hostname: System.get_env("DB_HOST") || "localhost",
  username: System.get_env("DB_USER") || "postgres",
  password: System.get_env("DB_PASSWORD") || "postgres",
  database: System.get_env("DB_NAME") || "elpaso_prod",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE") || "10")
