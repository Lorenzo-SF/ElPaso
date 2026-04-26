defmodule ElPaso do
  @moduledoc """
  ElPaso - Multi-model LLM proxy for Elixir.

  ElPaso is a comprehensive multi-model inference proxy that provides:

  - Smart routing between multiple local and remote LLMs
  - Portable session context across models 
  - Engine adapters for llama.cpp, Ollama, vLLM, OpenAI, Anthropic, and more
  - HTTP API compliant with OpenAI specification
  - Telemetry and Prometheus metrics
  - JWT authentication and rate limiting
  - CLI management tools
  - Context layers: prefix, summary, semantic, window
  - Model lifecycle management with auto-start/stop
  - Cluster support for distributed deployments

  ## Core Components

  ### HTTP API Endpoints
  - `/v1/chat/completions` - OpenAI compatible chat completions
  - `/v1/messages` - Anthropic compatible messages  
  - `/v1/messages_stream` - Anthropic streaming
  - `/v1/models` - Model listing
  - `/health` - Health check
  - `/status` - System status with quality degradation alerts
  - `/metrics` - Prometheus metrics
  - `/auth/token` - JWT authentication
  - `/admin/*` - Admin endpoints

  ### Engine Adapters
  - LlamaServer adapter (llama.cpp)
  - OpenAI adapter (OpenAI API)
  - VLLM adapter (vLLM serving)  
  - Anthropic adapter (Claude API)
  - Ollama adapter (local Ollama models)
  - AirLLMWrapper (custom engines)

  ### Context Management
  - Portable Session Context with layers:
    * Prefix layer (canonical prompt)
    * Summary layer (incremental summarization)  
    * Semantic layer (vector search)
    * Window layer (sliding window)
  - Token estimation and budget management
  - PostgreSQL persistence for sessions and messages

  ### Domain Logic
  - Heuristic Router for intelligent model selection
  - Model Manager for lifecycle control
  - AutoTuner for adaptive routing
  - Router Analyzer for quality degradation detection

  ### CLI Commands
  - `mix elpaso init` - Initialize system
  - `mix elpaso engine` - Manage engines  
  - `mix elpaso model` - Manage models
  - `mix elpaso router tune` - Auto-tune routing
  - `mix elpaso bench` - Benchmark models

  ## Quick Start

  ```bash
  # Initialize the system
  mix elpaso init

  # Add an engine (e.g. Ollama)
  mix elpaso engine add ollama

  # Add a model  
  mix elpaso model add fast --engine ollama

  # Start the server
  mix run --no-halt
  ```

  ## Configuration

  ElPaso loads configuration from `~/.config/elpaso/elpaso.conf` with fallback to environment variables.
  """

  @doc """
  Hello world.

  ## Examples

      iex> ElPaso.hello()
      :world

  """
  def hello do
    :world
  end
end
