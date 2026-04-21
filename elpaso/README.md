# ElPaso v1.1

## Madurez operacional y contexto semántico

Esta versión introduce mejoras operacionales y funcionalidades avanzadas para hacer el sistema más robusto para uso diario continuo.

### Características implementadas en V1.1:

- **Capa 3 del Contexto Portable**: Soporte para búsqueda semántica usando embeddings
- **Tokenizadores reales**: Implementación de backends de tokenización (tiktoken)
- **Overrides por request**: Soporte para configurar sesiones dinámicas mediante `elpaso` en las solicitudes
- **Comandos CLI**: `mix elpaso context show`, `mix elpaso embeddings rebuild`, `mix elpaso embeddings stats`
- **Migrador de configuración**: Soporte para migrar desde V1.0 a V1.1

### Estructura del proyecto:

```
lib/
├── el_paso/
│   ├── context/
│   │   ├── embedding_client.ex      # Cliente para generar embeddings
│   │   ├── semantic_retriever.ex     # Búsqueda semántica
│   │   ├── tokenizer.ex               # Tokenizadores reales
│   │   └── manager.ex                   # Gestor de contexto con semántica
│   ├── cli/
│   │   ├── commands/
│   │   │   ├── context.ex             # Comando para mostrar contexto
│   │   │   └── embeddings.ex      # Comandos para gestión de embeddings
│   ├── domain/
│   │   └── router.ex                  # Router con soporte para overrides
│   ├── http/
│   │   └── server.ex              # Servidor HTTP con soporte para overrides
│   ├── config/
│   │   ├── migrator.ex                  # Migrador de configuración
│   └── application.ex                 # Punto de entrada de la aplicación
└── mix.exs                           # Archivo de configuración Mix
```

### Configuración de embeddings:

La configuración ahora incluye una sección `embeddings` para controlar el uso de embeddings semánticos:

```json
{
  "embeddings": {
    "enabled": true,
    "model_id": "nomic-embed",
    "dimensions": 768,
    "embedding_timeout_ms": 5000,
    "batch_size": 50,
    "semantic_retrieval_k": 5,
    "min_similarity_threshold": 0.75,
    "ivfflat_build_threshold": 100
  }
}
```

### Comandos CLI disponibles:

- `mix elpaso context show` - Muestra información del contexto de una sesión
- `mix elpaso embeddings rebuild` - Reconstruye embeddings faltantes
- `mix elpaso embeddings stats` - Muestra estadísticas de cobertura de embeddings

## Dependencias requeridas:

- `:plug_cowboy` - Servidor HTTP
- `:finch` - Cliente HTTP
- `:jason` - Serialización JSON
- `:ecto_sql` - SQL para Ecto
- `:postgrex` - Driver PostgreSQL
- `:pgvector` - Soporte para vectores de embeddings
- `:nimble_options` - Manejo de opciones
- `:telemetry` - Monitoreo y métricas
- `:zaguan` - Framework TUI/CLI

## Desarrollo

Para comenzar a desarrollar:

1. Ejecutar `mix deps.get` para obtener las dependencias
2. Ejecutar `mix compile` para compilar el proyecto
3. Ejecutar `mix test` para correr las pruebas

## Licencia

Este proyecto está licenciado bajo los términos de la licencia MIT.