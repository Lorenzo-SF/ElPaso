defmodule ElPaso.Config.Wizard do
  @moduledoc """
  Wizard interactivo para configuración del sistema.

  Este módulo implementa un wizard interactivo para la configuración del sistema.
  """

  @doc """
  Inicia el wizard de configuración.
  """
  def start_wizard do
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
  def step_engine_type do
    # Stub: en producción usaría Zaguan.UI.Select
    # Por ahora, devuelve valor por defecto
    {:ok, "llama_server"}
  end

  @doc """
  Paso 2: Configuración de modelos.
  """
  def step_model_config do
    :ok
  end

  @doc """
  Paso 3: Confirmación y guardado de configuración.
  """
  def step_confirm do
    # Stub: en producción usaría Zaguan.UI.Confirm
    IO.puts("¿Guardar configuración? [S/n]")
    :ok
  end

  @doc """
  Configura el sistema con valores predeterminados.
  """
  def setup_defaults do
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
