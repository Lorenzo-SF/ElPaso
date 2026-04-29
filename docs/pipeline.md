# Pipeline de Inferencia

El pipeline de inferencia es el componente central del sistema que procesa las solicitudes de inferencia y las dirige a los motores adecuados.

## Arquitectura del Pipeline

El pipeline sigue este flujo:

1. **RequestParser** - Parsea la solicitud entrante
2. **Router** - Selecciona el modelo y motor adecuados
3. **Engine Dispatcher** - Ejecuta la inferencia en el motor seleccionado
4. **Response Handler** - Procesa y devuelve la respuesta

## Módulos Principales

- `ElPaso.Pipeline` - Módulo principal del pipeline
- `ElPaso.Engine.Adapter` - Adaptadores para diferentes motores de inferencia
- `ElPaso.Domain.Router` - Lógica de enrutamiento de modelos

## Uso

```elixir
# Procesar una solicitud normal
{:ok, response} = Pipeline.process_request("req123", "sess456", messages, options)

# Procesar una solicitud streaming
{:ok, response} = Pipeline.stream_request("req123", "sess456", messages, options)
```

## Adaptadores de Motores

El sistema soporta los siguientes motores de inferencia:

- OpenAI (API)
- Anthropic (API)  
- Ollama (local)
- llama.cpp (servidor local)

Cada adaptador implementa las funciones `execute` y `stream` para manejar llamadas normales y streaming.