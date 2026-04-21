defmodule ElPaso.Engine.OpenAIAdapter do
  @moduledoc """
  Adaptador para el motor OpenAI compatible con la API de OpenAI.
  
  Este módulo implementa las interfaces del motor base para interactuar con el backend de OpenAI.
  """

  alias ElPaso.Engine.Base

  @behaviour Base

  @impl Base
  def infer(model_id, prompt, opts) do
    # Implementación de llamada a la API de OpenAI
    # Esta es una implementación simplificada
    
    # En producción se usaría el cliente de OpenAI
    # con autenticación y manejo de errores
    
    {:ok, %{
      model: model_id,
      choices: [%{message: %{content: "Respuesta simulada de OpenAI"}}],
      usage: %{prompt_tokens: 10, completion_tokens: 20}
    }}
  end

  @impl Base
  def prepare_prefix(prefix_block, model_config) do
    # Preparar el bloque canónico para OpenAI
    # No requiere cambios especiales
    
    {:ok, prefix_block.content}
  end

  @impl Base
  def get_model_info(model_id) do
    # Obtener información del modelo OpenAI
    {:ok, %{
      id: model_id,
      name: "OpenAI #{model_id}",
      type: :openai,
      max_tokens: 4096,
      supports_system_prompt: true
    }}
  end

  @impl Base
  def is_available?(model_id) do
    # Verificar disponibilidad del modelo OpenAI
    true
  end

  @impl Base
  def start_model(model_id, opts) do
    # Arrancar modelo OpenAI (no aplica para OpenAI)
    {:ok, :openai_pid}
  end

  @impl Base
  def stop_model(model_id) do
    # Detener modelo OpenAI (no aplica para OpenAI)
    :ok
  end
end