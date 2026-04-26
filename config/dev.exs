import Config

# Configuración para entorno de desarrollo
config :elpaso,
  http_port: 4000,
  inference_server_url: "http://localhost:8081/v1",
  inference_api_key: "sk-local"

# Configuración de la base de datos para desarrollo
# Muy importante: localhost, no la IP del contenedor
config :elpaso, ElPaso.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "elpaso_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
