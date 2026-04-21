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
    # Obtener el bloque canónico (simplificado para prototipo)
    prefix_block = %{content: "", token_estimate: 0}

    # Obtener capas del contexto
    context_layers = %{
      summary: nil,
      window: [],
      semantic: []
    }

    # Estimar presupuesto
    with {:ok, budget} <- estimate_budget(context_spec, prefix_block) do
      # Ensamblar el prompt
      messages = build_messages(prefix_block, context_layers, current_message, context_spec)

      # Calcular estimación de tokens
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
    usable_tokens = context_spec.usable_tokens
    prefix_tokens = prefix_block.token_estimate

    if prefix_tokens > usable_tokens do
      {:error, :insufficient_token_budget}
    else
      budget = %{
        prefix: prefix_tokens,
        summary: 0,
        semantic: 0,
        window: 0,
        current: 0
      }

      {:ok, budget}
    end
  end

  # Funciones auxiliares para construir el prompt
  defp build_messages(prefix_block, context_layers, current_message, context_spec) do
    # Añadir bloque canónico como system si no hay soporte de system prompt
    messages =
      if !context_spec.supports_system_prompt do
        [%{role: "system", content: prefix_block.content}]
      else
        []
      end

    # Añadir resumen si existe
    messages =
      if context_layers.summary do
        messages ++ [%{role: "assistant", content: context_layers.summary}]
      else
        messages
      end

    # Añadir contexto semántico
    semantic_messages = Map.get(context_layers, :semantic, [])
    messages = messages ++ Enum.map(semantic_messages, &%{role: &1.role, content: &1.content})

    # Añadir ventana
    window_messages = Map.get(context_layers, :window, [])
    messages = messages ++ Enum.map(window_messages, &%{role: &1.role, content: &1.content})

    # Añadir mensaje actual del usuario
    messages ++ [%{role: "user", content: current_message}]
  end

  defp calculate_total_tokens(messages, prefix_block, _context_layers) do
    total = prefix_block.token_estimate

    # Estimar para cada mensaje
    Enum.reduce(messages, total, fn msg, acc ->
      acc + div(String.length(msg.content || ""), 3)
    end)
  end
end
