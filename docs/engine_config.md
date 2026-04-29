# Configuración del Pipeline

Este archivo contiene la configuración para los motores de inferencia.

## Motores Soportados

### OpenAI
```ini
[engine.openai]
type = "openai"
base_url = "https://api.openai.com/v1"
api_key = "sk-..."
timeout = 30
```

### Anthropic
```ini
[engine.anthropic]
type = "anthropic"
base_url = "https://api.anthropic.com/v1"
api_key = "sk-..."
timeout = 30
```

### Ollama
```ini
[engine.ollama]
type = "ollama"
base_url = "http://localhost:11434"
timeout = 30
```

### llama.cpp
```ini
[engine.llama_cpp]
type = "llama_cpp"
base_url = "http://localhost:8080"
timeout = 30
```

## Configuración de Modelos

```ini
[model.gpt-4]
engine = "openai"
max_tokens = 4096
temperature = 0.7
```

```ini
[model.claude-3]
engine = "anthropic"
max_tokens = 4096
temperature = 0.7
```

```ini
[model.llama2]
engine = "ollama"
max_tokens = 2048
temperature = 0.7
```