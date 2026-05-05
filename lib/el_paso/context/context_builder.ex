defmodule ElPaso.Context.ContextBuilder do
  @moduledoc """
  Construye el prompt completo que se enviará al modelo, combinando:
    1. System prompt de la personalidad
    2. Contexto de sesión compartido (Sala Común)
    3. Ventana deslizante de mensajes recientes
    4. Mensaje actual del usuario

  Respeta el límite de tokens del modelo destino.
  """

  alias ElPaso.Context.TokenCounter

  @default_max_tokens 4096
  @system_overhead_ratio 0.25
  @max_history_messages 10

  @doc """
  Construye la lista de mensajes para enviar al modelo.

  Argumentos:
    - context: mapa devuelto por SessionContext.get_context/2
    - user_message: el mensaje actual del usuario
    - model_max_tokens: límite de tokens del modelo destino
    - personality_system_prompt: prompt de sistema de la personalidad

  Devuelve:
    Lista de mensajes [{role, content}] lista para enviar al engine.
  """
  @spec build(map(), String.t(), integer(), String.t() | nil) :: [map()]
  def build(context, user_message, model_max_tokens \\ @default_max_tokens, personality_system_prompt \\ nil) do
    system_budget = trunc(model_max_tokens * @system_overhead_ratio)
    history_budget = model_max_tokens - system_budget - TokenCounter.count(user_message)

    # 1. System prompt base de la personalidad
    system_content = personality_system_prompt || context[:system_prompt] || ""

    # 2. Añadir contexto de sesión compartido
    session_context = build_session_context_block(context)

    # 3. Combinar y truncar al budget
    full_system = TokenCounter.truncate(system_content <> "\n\n" <> session_context, system_budget)

    # 4. Ventana deslizante de historial reciente
    history = build_history_block(context[:recent_context] || [], history_budget)

    # 5. Construir lista final
    messages = [%{role: "system", content: full_system}]
    messages = messages ++ history
    messages = messages ++ [%{role: "user", content: user_message}]

    messages
  end

  defp build_session_context_block(context) do
    parts = []

    parts =
      if context[:session_summary] && context[:session_summary] != "" do
        parts ++ ["[CONTEXTO DE SESIÓN — lo que se ha hecho hasta ahora]\n#{context[:session_summary]}"]
      else
        parts
      end

    parts =
      if context[:personality_switch_history] && context[:personality_switch_history] != "" do
        parts ++ ["[HISTORIAL DE ESPECIALISTAS]\nHan intervenido: #{context[:personality_switch_history]}"]
      else
        parts
      end

    parts =
      if is_map(context[:knowledge_board]) and map_size(context[:knowledge_board]) > 0 do
        kb = Enum.map(context[:knowledge_board], fn {k, v} -> "- #{k}: #{v}" end)
        parts ++ ["[INFORMACIÓN COMPARTIDA]\n#{Enum.join(kb, "\n")}"]
      else
        parts
      end

    Enum.join(parts, "\n\n")
  end

  defp build_history_block([], _budget), do: []

  defp build_history_block(recent_messages, budget) do
    recent_messages
    |> Enum.reverse()
    |> Enum.take(@max_history_messages)
    |> Enum.reduce({[], budget}, fn msg, {acc, remaining} ->
      content = Map.get(msg, :content) || Map.get(msg, "content") || ""
      tokens = TokenCounter.count(content)

      if tokens <= remaining do
        {[%{role: msg[:role] || msg["role"] || "user", content: content} | acc], remaining - tokens}
      else
        {acc, 0}
      end
    end)
    |> elem(0)
  end
end
