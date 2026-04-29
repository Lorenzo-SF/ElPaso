# Ejemplo de Uso del Pipeline

Este documento muestra cómo usar el pipeline desde la línea de comandos.

## Comandos CLI

Para usar el pipeline desde CLI, primero necesitas tener motores y modelos configurados en la base de datos:

```bash
# Añadir un motor OpenAI
elpaso engine add --name openai --type openai --base-url https://api.openai.com/v1

# Añadir un modelo
elpaso model add --name gpt-4 --engine openai --max-tokens 4096

# Añadir una personalidad
elpaso personality add --name default --system-prompt "Eres un asistente útil."

# Añadir un perfil
elpaso profile add --name my-profile --model gpt-4 --engine openai --personality default
```

## Ejecución del Pipeline

Una vez configurado, puedes usar el pipeline desde el CLI:

```bash
# Procesar una solicitud
elpaso context chat --profile my-profile --message "¿Cuál es la capital de Francia?"

# Procesar con streaming
elpaso context stream --profile my-profile --message "Escribe un poema sobre el océano"
```

## API HTTP

También puedes usar el pipeline a través de la API HTTP:

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Hola"}]
  }'
```