# ElPaso

**Runtime**: Elixir 1.19.5-otp-28

ElPaso es un proxy de inferencia multi-modelo escrito en Elixir. Su objetivo es
proporcionar un único endpoint de acceso a múltiples modelos LLM, permitiendo al
usuario trabajar con ellos de forma transparente sin necesidad de gestionar cada
motor por separado.

El foco principal son los modelos locales: llama.cpp (via llama-server), vLLM,
Ollama y otros runtimes compatibles con la API de OpenAI. Sin renunciar a proveedores
externos como OpenAI o Anthropic cuando sean necesarios.

ElPaso decide qué modelo usar en cada momento, gestiona el ciclo de vida de los
procesos de motor, mantiene el contexto de conversación portable entre modelos, y
garantiza que el cambio entre ellos sea invisible para el usuario.

## Características

- Soporte multi-modelo con tolerancia a fallos
- Gestión del ciclo de vida de motores de inferencia
- Contexto de conversación portable
- Integración con frameworks TUI/CLI (Zaguan)
- Cache LRU+TTL para respuestas
- Sistema de enrutamiento inteligente

## Estructura del proyecto

```
lib/
├── el_paso/
│   ├── application.ex          # Punto de entrada de la aplicación
│   ├── context/
│   │   ├── schemas/            # Schemas Ecto para tablas PostgreSQL
│   │   ├── session_supervisor.ex         # Supervisor de sesiones
│   │   └── summarization_supervisor.ex  # Supervisor de procesamiento de resúmenes
│   ├── domain/
│   │   ├── model_manager.ex              # Gestor de motores de inferencia
│   │   └── output_cache.ex                 # Cache para respuestas
│   ├── engine/
│   │   ├── dispatcher.ex       # Punto de entrada único para inferencia
│   │   ├── chat_template.ex              # Formateador de mensajes
│   │   └── ollama.ex                     # Wrapper para Ollama
│   └── http/
│       └── server.ex                     # Servidor HTTP para APIs REST
└── mix.exs                           # Archivo de configuración Mix
```

## Dependencias

- `:plug_cowboy` - Servidor HTTP
- `:finch` - Cliente HTTP
- `:jason` - Serialización JSON
- `:ecto_sql` - SQL para Ecto
- `:postgrex` - Driver PostgreSQL
- `:pgvector` - Soporte para vectores de embeddings
- `:nimble_options` - Manejo de opciones
- `:telemetry` - Monitoreo y métricas
- `:zaguan` - Framework TUI/CLI

## Configuración

La configuración se encuentra en `config/`. Los archivos principales son:

- `config/config.exs` - Configuración base
- `config/dev.exs` - Configuración de desarrollo
- `config/test.exs` - Configuración de pruebas
- `config/runtime.exs` - Configuración de tiempo de ejecución

## Desarrollo

Para comenzar a desarrollar:

1. Ejecutar `mix deps.get` para obtener las dependencias
2. Ejecutar `mix compile` para compilar el proyecto
3. Ejecutar `mix test` para correr las pruebas

## Licencia

Este proyecto está licenciado bajo los términos de la licencia MIT.