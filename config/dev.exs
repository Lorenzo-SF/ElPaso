import Config

# Configuración para entorno de desarrollo
config :elpaso,
  http_port: 4000,
  inference_server_url: "http://localhost:8081/v1",
  inference_api_key: "sk-local"
