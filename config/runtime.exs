import Config
import Config

# Configuración básica para el entorno de desarrollo
config :elpaso,
  # Puerto por defecto para el servidor HTTP
  http_port: 4000,
  # URL base del servidor de inferencia local
  inference_server_url: "http://localhost:8081/v1",
  # API key para el servidor local
  inference_api_key: "sk-local"

# Configuración de seguridad básica
config :elpaso, :security,
  api_key: nil,
  rate_limit_rpm: 60,
  max_message_length_chars: 32768,
  cors_enabled: false

# Configuración de modelos
config :elpaso, :models,
  fast: %{
    id: "fast",
    name: "Gemma 3 4B (rápido)",
    engine: "llama_server",
    ram_mb: 4200,
    vram_mb: 3800,
    routing: %{
      priority: 1,
      complexity_ceiling: 0.7,
      cold_start_estimate_ms: 8000,
      task_affinity: %{
        code: 0.8,
        reasoning: 0.9,
        summarization: 0.6,
        question_answer: 0.3,
        creative: 0.7,
        translation: 0.4,
        unknown: 0.5
      }
    }
  },
  heavy: %{
    id: "heavy",
    name: "Llama 3 8B (pesado)",
    engine: "llama_server",
    ram_mb: 8000,
    vram_mb: 7000,
    routing: %{
      priority: 2,
      complexity_ceiling: 1.0,
      cold_start_estimate_ms: 15000,
      task_affinity: %{
        code: 0.9,
        reasoning: 0.8,
        summarization: 0.7,
        question_answer: 0.6,
        creative: 0.5,
        translation: 0.4,
        unknown: 0.5
      }
    }
  }

# Configuración de la base de datos para producción (runtime)
config :elpaso, ElPaso.Repo,
  hostname: System.get_env("DB_HOST") || "localhost",
  username: System.get_env("DB_USER") || "postgres",
  password: System.get_env("DB_PASSWORD") || "postgres",
  database: System.get_env("DB_NAME") || "elpaso_prod",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE") || "10")
