defmodule ElPaso.Context.TokenCounter do
  @moduledoc """
  Estimador de tokens para controlar el presupuesto de contexto.

  Usa heurística chars/4 como aproximación rápida.
  Futuro: integración con tiktoken o el tokenizer nativo del modelo.
  """

  @chars_per_token 4.0

  @doc "Estima el número de tokens en un texto."
  @spec count(String.t()) :: non_neg_integer()
  def count(text) when is_binary(text) do
    (String.length(text) / @chars_per_token) |> ceil()
  end

  @doc "Estima tokens de una lista de mensajes."
  @spec count_messages([map()]) :: non_neg_integer()
  def count_messages(messages) when is_list(messages) do
    Enum.reduce(messages, 0, fn msg, acc ->
      content = Map.get(msg, :content) || Map.get(msg, "content") || ""
      acc + count(content)
    end)
  end

  @doc "Verifica si los mensajes caben en el budget de tokens."
  @spec fits_in_budget?([map()], integer()) :: boolean()
  def fits_in_budget?(messages, max_tokens) do
    count_messages(messages) <= max_tokens
  end

  @doc """
  Trunca un texto para que quepa en un presupuesto de tokens,
  intentando mantener frases completas.
  """
  @spec truncate(String.t(), integer()) :: String.t()
  def truncate(text, max_tokens) when is_binary(text) do
    current = count(text)

    if current <= max_tokens do
      text
    else
      char_limit = max_tokens * 4
      truncated = String.slice(text, 0, char_limit) |> String.trim()

      # Intentar cortar en un punto de frase
      case :binary.last(truncated) do
        ?. -> truncated
        ?! -> truncated
        ?? -> truncated
        _ ->
          # Buscar el último punto antes del corte
          case String.last(truncated) do
            "." -> truncated
            _ ->
              last_period = truncated |> String.reverse() |> String.split(".", parts: 2)
              case last_period do
                [_rest, before] -> String.reverse(before) <> "."
                _ -> truncated
              end
          end
      end <> "\n[...truncated by token budget...]"
    end
  end
end
