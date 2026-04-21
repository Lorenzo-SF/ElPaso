defmodule ElPaso.Context.Builder do
  @moduledoc """
  Constructor del contexto de sesión portable para inferencia.
  
  Este módulo ensambla los diferentes componentes del contexto según las capas definidas:
  - Bloque canónico (PrefixManager)
  - Resumen incremental (Compression Layer)
  - Contexto recuperado semánticamente (Relevance Layer)
  - Ventana deslizante (Recency Layer)
  - Mensaje actual del usuario
  """

  alias ElPaso.Context.PrefixManager
  alias ElPaso.Context.Storage
  alias ElPaso.Context.Schemas.Message

  # Estructura para el prompt construido
  defmodule BuiltPrompt do
    @moduledoc """
    Estructura que representa un prompt construido listo para ser enviado a un motor de inferencia.
    """

    defstruct [
      :messages,
      :system,
      :token_estimate,
      :budget_used,
      :model_id,
      :session_id,
      :built_at
    ]

    @type t :: %BuiltPrompt{
            messages: [%{role: String.t(), content: String.t()}],
            system: String.t() | nil,
            token_estimate: non_neg_integer(),
            budget_used: %{
              prefix: non_neg_integer(),
              summary: non_neg_integer(),
              semantic: non_neg_integer(),
              window: non_neg_integer(),
              current: non_neg_integer()
            },
            model_id: String.t(),
            session_id: String.t(),
            built_at: DateTime.t()
          }
  end

  @doc """
  Construye el prompt completo para una sesión.
  
  Recibe los datos de contexto y el especificador del modelo destino,
  y devuelve un BuiltPrompt listo para enviar a un motor de inferencia.
  """
  def build(session_id, current_message, context_spec) do
    # Obtener el bloque canónico
    with {:ok, prefix_block} <- PrefixManager.get(session_id),
         {:ok, context_layers} <- Storage.get_context_layers(session_id, context_spec),
         {:ok, budget} <- estimate_budget(context_spec, prefix_block) do
      # Ensamblar el prompt siguiendo el orden definido
      messages = build_messages(prefix_block, context_layers, current_message, context_spec)

      # Calcular estimación total de tokens
      token_estimate = calculate_total_tokens(messages, prefix_block, context_layers)

      # Crear BuiltPrompt
      built_prompt = %BuiltPrompt{
        messages: messages,
        system: if(context_spec.supports_system_prompt, do: prefix_block.content, else: nil),
        token_estimate: token_estimate,
        budget_used: budget,
        model_id: context_spec.model_id,
        session_id: session_id,
        built_at: DateTime.utc_now()
      }

      {:ok, built_prompt}
    else
      error -> error
    end
  end

  @doc """
  Estima el presupuesto de tokens para cada capa del contexto.
  """
  def estimate_budget(context_spec, prefix_block) do
    # Calcular el espacio disponible en tokens
    usable_tokens = context_spec.usable_tokens
    
    # Calcular el espacio usado por el bloque canónico
    prefix_tokens = prefix_block.token_estimate
    
    # Estimar espacio para las capas dinámicas
    summary_tokens = 0
    semantic_tokens = 0
    window_tokens = 0
    
    # Verificar que hay suficiente espacio
    if prefix_tokens > usable_tokens do
      {:error, :insufficient_token_budget}
    else
      budget = %{
        prefix: prefix_tokens,
        summary: summary_tokens,
        semantic: semantic_tokens,
        window: window_tokens,
        current: 0
      }
      
      {:ok, budget}
    end
  end

  # Funciones auxiliares para construir el prompt
  defp build_messages(prefix_block, context_layers, current_message, context_spec) do
    messages = []

    # Añadir el bloque canónico como primer mensaje (si no es system)
    if !context_spec.supports_system_prompt do
      messages = [messages, %{role: "system", content: prefix_block.content}]
    end

    # Añadir resumen incremental si existe
    summary_content = Map.get(context_layers, :summary, nil)
    if summary_content != nil do
      messages = [messages, %{role: "assistant", content: summary_content}]
    end

    # Añadir contexto recuperado semánticamente si está activo
    semantic_messages = Map.get(context_layers, :semantic, [])
    messages = [messages | Enum.map(semantic_messages, &%{role: &1.role, content: &1.content})]

    # Añadir ventana deslizante
    window_messages = Map.get(context_layers, :window, [])
    messages = [messages | Enum.map(window_messages, &%{role: &1.role, content: &1.content})]

    # Añadir mensaje actual del usuario
    messages = [messages, %{role: "user", content: current_message}]

    messages
  end

  defp calculate_total_tokens(messages, prefix_block, context_layers) do
    # Calcular tokens totales estimados
    total = prefix_block.token_estimate
    
    summary_content = Map.get(context_layers, :summary, nil)
    if summary_content != nil do
      total = total + estimate_tokens_for_string(summary_content)
    end

    semantic_messages = Map.get(context_layers, :semantic, [])
    total = total + Enum.reduce(semantic_messages, 0, fn msg, acc -> 
      acc + estimate_tokens_for_string(msg.content) 
    end)

    window_messages = Map.get(context_layers, :window, [])
    total = total + Enum.reduce(window_messages, 0, fn msg, acc -> 
      acc + estimate_tokens_for_string(msg.content) 
    end)

    total
  end

  defp estimate_tokens_for_string(content) do
    # Estimación simple basada en caracteres (3 caracteres ≈ 1 token)
    div(String.length(content), 3)
  end
end