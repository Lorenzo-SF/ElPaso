import Config

# Configuración para entorno de desarrollo
config :elpaso,
  http_port: 4000,
  inference_server_url: "http://localhost:8081/v1",
  inference_api_key: "sk-local"

# ── V4.0: PersonalityLoadManager ──────────────────────────────────────
# Controla cuántas personalidades pueden estar cargadas simultáneamente.
# - max_parallel: máximo de modelos en paralelo (1 con llama-server local)
# - protected_personalities: nunca serán desalojadas (classifier-router = motor de decisiones)
config :elpaso, :personality_load,
  max_parallel: 2,
  protected_personalities: ["classifier-router"]

# Logger en desarrollo: debug + metadata
config :logger, :console,
  level: :debug,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

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
