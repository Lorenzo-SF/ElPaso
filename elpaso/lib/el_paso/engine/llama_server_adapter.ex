defmodule ElPaso.Engine.LlamaServerAdapter do
  @moduledoc """
  Adaptador para el motor llama-server compatible con llama.cpp.
  
  Este módulo implementa las interfaces del motor base para interactuar con el backend de llama-server.
  """

  alias ElPaso.Engine.Base

  @behaviour Base

  @impl Base
  def infer(model_id, prompt, opts) do
    # Implementación de llamada a llama-server
    # Esta es una implementación simplificada
    
    # En producción se usaría el cliente HTTP para llama-server
    # con autenticación y manejo de errores
    
    {:ok, %{
      model: model_id,
      choices: [%{message: %{content: "Respuesta simulada de llama-server"}}],
      usage: %{prompt_tokens: 15, completion_tokens: 25}
    }}
  end

  @impl Base
  def prepare_prefix(prefix_block, model_config) do
    # Preparar el bloque canónico para llama-server
    # llama-server no requiere cambios especiales
    
    {:ok, prefix_block.content}
  end

  @impl Base
  def get_model_info(model_id) do
    # Obtener información del modelo llama-server
    {:ok, %{
      id: model_id,
      name: "Llama #{model_id}",
      type: :llama_server,
      max_tokens: 4096,
      supports_system_prompt: true
    }}
  end

  @impl Base
  def is_available?(model_id) do
    # Verificar disponibilidad del modelo llama-server
    true
  end

  @impl Base
  def start_model(model_id, opts) do
    # Arrancar modelo llama-server
    # En producción se usaría el proceso de llama-server
    
    {:ok, :llama_pid}
  end

  @impl Base
  def stop_model(model_id) do
    # Detener modelo llama-server
    :ok
  end
end