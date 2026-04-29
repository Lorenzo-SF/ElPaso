# Fase 4: Contexto y Sesiones

Esta fase implementa el manejo completo del contexto de conversación, incluyendo sesiones, almacenamiento de mensajes, embeddings y resúmenes.

## Componentes Implementados

### 4.1 Storage Real
- `Storage.create_session()` → Ecto insert
- `Storage.get_session()` → Ecto query
- `Storage.get_all_messages()` → Ecto query con orden
- `Storage.get_latest_summary()` → Ecto query
- `Context.Manager.reload_session()` debe usar Storage.get_session()

### 4.2 Embeddings
- `EmbeddingClient` real para generar embeddings usando modelos locales o APIs externas
- Índice IVFFlat en pgvector para búsqueda semántica
- `rebuild_embeddings` genera embeddings para mensajes sin embedding

### 4.3 Summarization
- `SummarizationWorker` que invoca modelos para generar resúmenes
- `SummarizationSupervisor` que supervisa workers de resumen
- Guardar resúmenes en DB con esquema existente

## Uso del Contexto

```elixir
# Crear o obtener una sesión
{:ok, session_id, session_state} = ElPaso.Context.Manager.get_or_create_session()

# Agregar mensajes a la sesión
ElPaso.Context.Storage.create_message(%{
  session_id: session_id,
  role: "user",
  content: "Hola, ¿cómo estás?"
})

# Obtener todos los mensajes
messages = ElPaso.Context.Storage.get_all_messages(session_id)

# Generar resumen de conversación
ElPaso.Context.SummarizationWorker.summarize_session(session_id)
```

## Configuración

La configuración para embeddings se puede definir en `elpaso.conf`:

```ini
[engines.embedding]
timeout = 30
```

Los modelos de embedding se definen como cualquier otro modelo, con el tipo de motor adecuado.