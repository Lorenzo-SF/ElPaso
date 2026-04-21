import Config

# Configura el logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: :debug,
  metadata: [:request_id]

# Configuración de Ecto
config :elpaso, ecto_repos: [ElPaso.Repo]

# Configuración de la aplicación
config :elpaso,
  # Puerto por defecto para el servidor HTTP
  http_port: 4000,
  # URL base del servidor de inferencia local
  inference_server_url: "http://localhost:8081/v1",
  # API key para el servidor local
  inference_api_key: "sk-local"
