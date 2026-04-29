import Config
IO.puts("[test.exs] Loading test configuration...")

# Configuración para entorno de prueba
config :elpaso,
  http_port: 4000,
  inference_server_url: "http://localhost:8081/v1",
  inference_api_key: "sk-local"

# Configuración de la base de datos para pruebas
config :elpaso, ElPaso.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  hostname: "localhost",
  username: "postgres",
  password: "postgres",
  database: "elpaso_test",
  port: 5432
