defmodule ElPaso.Config do
  @moduledoc """
  Módulo de configuración del sistema.
  
  Este módulo gestiona la carga y validación de la configuración del sistema.
  """

  alias ElPaso.Context.Schemas.Session

  @doc """
  Carga la configuración desde el archivo de configuración.
  """
  def load_config() do
    # Cargar configuración desde config/config.exs
    # Esta implementación es simplificada
    
    %{
      system: %{
        api_key: nil,
        rate_limit_rpm: 60,
        max_message_length_chars: 32768,
        cors_enabled: false
      },
      models: %{
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
      }
    }
  end

  @doc """
  Valida la configuración.
  """
  def validate_config(config) do
    # Validar que todos los modelos tienen las configuraciones necesarias
    
    if Map.has_key?(config, :models) and config.models != %{} do
      {:ok, config}
    else
      {:error, "Configuración inválida: no hay modelos definidos"}
    end
  end

  @doc """
  Obtiene la configuración del modelo.
  """
  def get_model_config(model_id) do
    # Obtener la configuración específica de un modelo
    config = load_config()
    Map.get(config.models, model_id, %{})
  end

  @doc """
  Obtiene el especificador de contexto para un modelo.
  """
  def context_spec_for(model_id) do
    # Construir el especificador de contexto basado en la configuración del modelo
    
    config = load_config()
    model_config = Map.get(config.models, model_id, %{})
    
    %{
      model_id: model_id,
      max_tokens: Map.get(model_config, :max_tokens, 4096),
      reserved_for_output: 256,
      usable_tokens: Map.get(model_config, :max_tokens, 4096) - 256,
      supports_system_prompt: true
    }
  end
end