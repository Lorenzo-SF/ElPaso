import Config

# ==============================================================
# Configuración de producción - V3.0
# Cargar desde variables de entorno
# ==============================================================

# Puerto HTTP
config :elpaso,
  http_port: String.to_integer(System.get_env("HTTP_PORT") || "4000")

# ==============================================================
# Autenticación JWT
# ==============================================================
config :elpaso,
  jwt_secret:
    System.get_env("ELPASO_JWT_SECRET") ||
      raise("ELPASO_JWT_SECRET no definida en producción")

# ==============================================================
# API keys configuradas
# ==============================================================
config :elpaso,
  api_keys:
    System.get_env("ELPASO_API_KEYS", "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))

# ==============================================================
# Cost management
# ==============================================================
config :elpaso, :cost_management,
  enabled: System.get_env("COST_ENABLED", "false") == "true",
  daily_usd: String.to_float(System.get_env("COST_DAILY_USD", "100.0")),
  alert_at_pct: String.to_integer(System.get_env("COST_ALERT_PCT", "80"))

# ==============================================================
# Storage S3 (opcional)
# ==============================================================
config :elpaso, :s3,
  enabled: System.get_env("S3_ENABLED", "false") == "true",
  bucket: System.get_env("S3_BUCKET", ""),
  region: System.get_env("AWS_REGION", "us-east-1"),
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY")

# ==============================================================
# Modelo de inferencia
# ==============================================================
config :elpaso,
  inference_server_url: System.get_env("INFERENCE_SERVER_URL", "http://localhost:8081/v1"),
  inference_api_key: System.get_env("INFERENCE_API_KEY", "sk-local")

# ==============================================================
# Clustering
# ==============================================================
config :elpaso, :cluster,
  enabled: System.get_env("CLUSTER_ENABLED", "false") == "true",
  node_name: System.get_env("CLUSTER_NODE_NAME"),
  role: String.to_atom(System.get_env("CLUSTER_ROLE", "both")),
  discovery: System.get_env("CLUSTER_DISCOVERY", "static"),
  coordinator_nodes:
    System.get_env("CLUSTER_COORDINATOR_NODES", "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "")),
  worker_nodes:
    System.get_env("CLUSTER_WORKER_NODES", "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))

# ==============================================================
# Database (usar runtime.exs para estos valores)
# ==============================================================
config :elpaso, ElPaso.Repo,
  hostname: System.get_env("DB_HOST") || "localhost",
  username: System.get_env("DB_USER") || "postgres",
  password: System.get_env("DB_PASSWORD") || "postgres",
  database: System.get_env("DB_NAME") || "elpaso_prod",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE") || "10")
