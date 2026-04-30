defmodule ElPaso.Config.Wizard do
  @moduledoc """
  Wizard interactivo para configuración del sistema.

  Este módulo implementa un wizard interactivo para la configuración del sistema,
  utilizando `IO.gets/1` estándar para la entrada de usuario y los helpers
  semánticos de `ElPaso.CLI.Output` para la salida formateada.
  """

  alias ElPaso.CLI.Output

  @doc """
  Inicia el wizard de configuración interactivo.
  """
  def start_wizard do
    Output.section("Wizard de configuración ElPaso")
    Output.info("Este asistente te guiará por la configuración inicial del sistema.")

    # Paso 1: Selección del tipo de motor
    step_engine_type()

    # Paso 2: Configuración de modelos
    step_model_config()

    # Paso 3: Confirmación y guardado
    step_confirm()

    Output.success("Wizard completado.")
    :ok
  end

  @doc """
  Paso 1: Selección del tipo de motor.

  En modo no interactivo (por defecto) devuelve el motor por defecto.
  Para interacción real, usa `step_engine_type_interactive/0`.
  """
  def step_engine_type do
    Output.divider("Paso 1: Tipo de motor")

    Output.alert_box(
      [
        "Opciones disponibles:",
        "  1. llama_server  — Servidor local llama.cpp",
        "  2. ollama        — Ollama local",
        "  3. openai        — API de OpenAI (remota)",
        "  4. anthropic     — API de Anthropic (remota)",
        "  5. vllm          — Servidor vLLM local"
      ],
      type: :info
    )

    # Stub: Zaguan no expone widgets de prompt CLI simple (solo componentes TUI).
    # Para un wizard interactivo real se usaría IO.gets o una librería de prompts.
    {:ok, "llama_server"}
  end

  @doc """
  Versión interactiva del paso 1. Lee la opción del usuario vía `IO.gets`.
  """
  def step_engine_type_interactive do
    Output.divider("Paso 1: Tipo de motor")

    Output.alert_box(
      [
        "Opciones disponibles:",
        "  1. llama_server  — Servidor local llama.cpp",
        "  2. ollama        — Ollama local",
        "  3. openai        — API de OpenAI (remota)",
        "  4. anthropic     — API de Anthropic (remota)",
        "  5. vllm          — Servidor vLLM local"
      ],
      type: :info
    )

    choice =
      IO.gets("Selecciona una opción [1-5] (por defecto 1): ")
      |> case do
        :eof -> "1"
        {:error, _} -> "1"
        input -> String.trim(input)
      end

    engine =
      case choice do
        "2" -> "ollama"
        "3" -> "openai"
        "4" -> "anthropic"
        "5" -> "vllm"
        _ -> "llama_server"
      end

    Output.success("Motor seleccionado: #{engine}")
    {:ok, engine}
  end

  @doc """
  Paso 2: Configuración de modelos.
  """
  def step_model_config do
    Output.divider("Paso 2: Configuración de modelos")

    rows = [
      ["fast", "Gemma 3 4B", "llama_server", "4200 MB", "3800 MB"],
      ["heavy", "Llama 3 8B", "llama_server", "8000 MB", "7000 MB"]
    ]

    Output.data_table(
      ["ID", "Nombre", "Engine", "RAM", "VRAM"],
      rows
    )

    Output.info("Configuración por defecto cargada.")
    :ok
  end

  @doc """
  Paso 3: Confirmación y guardado de configuración.
  """
  def step_confirm do
    Output.divider("Paso 3: Confirmación")

    Output.warning("¿Guardar configuración? [S/n]")

    :ok
  end

  @doc """
  Versión interactiva del paso 3. Lee la confirmación del usuario vía `IO.gets`.
  """
  def step_confirm_interactive do
    Output.divider("Paso 3: Confirmación")

    Output.warning("¿Guardar configuración? [S/n]")

    choice =
      IO.gets("Tu respuesta: ")
      |> case do
        :eof -> "s"
        {:error, _} -> "s"
        input -> String.trim(input) |> String.downcase()
      end

    if choice in ["s", "", "y", "yes"] do
      Output.success("Configuración guardada.")
      :ok
    else
      Output.info("Guardado cancelado.")
      :cancelled
    end
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

    Output.success("Configuración por defecto generada.")
    {:ok, config}
  end
end
