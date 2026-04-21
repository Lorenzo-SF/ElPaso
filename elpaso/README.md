# ElPaso v1.2

## Diagnóstico y ajuste fino

Esta versión introduce herramientas de diagnóstico avanzadas y capacidad de ajuste fino para mejorar el comportamiento del sistema.

### Características implementadas en V1.2:

- **Comandos de diagnóstico**: `mix elpaso router stats` para análisis estadístico
- **Ajuste automático**: `mix elpaso router tune` para sugerencias de ajuste
- **Benchmarking**: `mix elpaso bench` para pruebas de rendimiento
- **Diferencias de configuración**: `mix elpaso config reload` con diff visual
- **Exportación de sesiones**: Soporte para exportar conversaciones en múltiples formatos

### Estructura del proyecto:

```
lib/
├── el_paso/
│   ├── domain/
│   │   ├── router_stats.ex                # Estadísticas de routing
│   │   └── router_tuner.ex                # Ajuste automático de afinidades
│   ├── cli/
│   │   ├── commands/
│   │   │   ├── router_stats.ex        # Comando para estadísticas de routing
│   │   │   ├── router_tune.ex          # Comando para ajuste de routing
│   │   │   ├── bench.ex               # Comando para benchmarking
│   │   │   └── context.ex             # Comando para exportar sesiones
│   ├── config/
│   │   └── diff.ex                  # Diferencias en configuración
│   └── application.ex               # Punto de entrada de la aplicación
└── mix.exs                           # Archivo de configuración Mix
```

### Comandos disponibles:

- `mix elpaso router stats` - Muestra estadísticas de routing
- `mix elpaso router tune` - Analiza y sugiere ajustes de afinidades
- `mix elpaso bench` - Ejecuta benchmarks de rendimiento
- `mix elpaso config reload` - Recarga configuración con diff visual
- `mix elpaso context export` - Exporta conversaciones

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