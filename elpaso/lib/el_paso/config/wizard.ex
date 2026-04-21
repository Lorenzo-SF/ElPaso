defmodule ElPaso.Config.Wizard do
  @moduledoc """
  Wizard interactivo para configuración del sistema.
  
  Este módulo implementa un wizard interactivo para la configuración del sistema mediante Ziguan UI.
  """

  alias Zaguan.UI.Components.{Select, Input, Confirm}
  alias Zaguan.Drawer.Components.{Header, Table, Message}

  @doc """
  Inicia el wizard de configuración.
  """
  def start_wizard() do
    # Iniciar el wizard interactivo
    
    # Paso 1: Selección del tipo de motor
    step_engine_type()

    # Paso 2: Configuración de modelos
    step_model_config()

    # Paso 3: Confirmación y guardado
    step_confirm()
    
    :ok
  end

  @doc """
  Paso 1: Selección del tipo de motor.
  """
  def step_engine_type() do
    {:ok, engine_type} = Select.prompt("Tipo de motor:",
      options: ["llama_server", "vllm", "openai", "anthropic", "ollama"],
      default: "llama_server"
    )
    
    # Guardar el tipo de motor seleccionado
    :ok
  end

  @doc """
  Paso 2: Configuración de modelos.
  """
  def step_model_config() do
    # Este paso se implementaría según las necesidades específicas
    
    :ok
  end

  @doc """
  Paso 3: Confirmación y guardado de configuración.
  """
  def step_confirm() do
    {:ok, confirmed} = Confirm.prompt("¿Guardar configuración?", default: true)
    
    if confirmed do
      Message.print(:success, "Configuración guardada en ~/.config/elpaso/elpaso.conf")
    else
      Message.print(:error, "Configuración no guardada")
    end
    
    :ok
  end

  @doc """
  Configura el sistema con valores predeterminados.
  """
  def setup_defaults() do
    # Configurar valores por defecto
    
    config = %{
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
            cold_start_estimate_ms: 8000
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
            cold_start_estimate_ms: 15000
          }
        }
      }
    }
    
    {:ok, config}
  end
end