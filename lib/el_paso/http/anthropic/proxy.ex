defmodule ElPaso.HTTP.AnthropicProxy do
  @moduledoc """
  Convierte requests y respuestas entre formato Anthropic y formato interno de ElPaso.
  """

  # Struct temporal para request interno - definido primero
  defmodule InternalRequest do
    defstruct [
      :messages,
      :system_override,
      :model_hint,
      :personality_hint,
      :max_tokens,
      :temperature,
      :stream,
      :content,
      :finish_reason,
      :prompt_tokens,
      :completion_tokens
    ]
  end

  @doc """
  Convierte un request Anthropic al formato interno de ElPaso.
  """
  def from_anthropic(anthropic_params) when is_map(anthropic_params) do
    messages = Map.get(anthropic_params, "messages", [])
    system = Map.get(anthropic_params, "system")

    # V4.0: preservar modelo y personalidad solicitados
    requested_model = Map.get(anthropic_params, "model")
    personality = Map.get(anthropic_params, "personality")

    %InternalRequest{
      messages: messages,
      system_override: system,
      # Mapear modelo Anthropic a hint interno
      model_hint: map_anthropic_model(requested_model),
      personality_hint: personality,
      max_tokens: Map.get(anthropic_params, "max_tokens"),
      temperature: Map.get(anthropic_params, "temperature"),
      stream: Map.get(anthropic_params, "stream", false)
    }
  end

  @doc """
  Convierte una respuesta interna de ElPaso al formato Anthropic.
  """
  def to_anthropic(%InternalRequest{} = internal_response, original_model) do
    %{
      "id" => "msg_#{generate_id()}",
      "type" => "message",
      "role" => "assistant",
      "content" => [%{"type" => "text", "text" => internal_response.content}],
      "model" => original_model,
      "stop_reason" => map_finish_reason(internal_response.finish_reason),
      "usage" => %{
        "input_tokens" => internal_response.prompt_tokens,
        "output_tokens" => internal_response.completion_tokens
      }
    }
  end

  def to_anthropic(%{} = internal_response, original_model) do
    %{
      "id" => "msg_#{generate_id()}",
      "type" => "message",
      "role" => "assistant",
      "content" => [%{"type" => "text", "text" => Map.get(internal_response, "content", "")}],
      "model" => original_model,
      "stop_reason" => map_finish_reason(Map.get(internal_response, :finish_reason, :stop)),
      "usage" => %{
        "input_tokens" => Map.get(internal_response, :prompt_tokens, 0),
        "output_tokens" => Map.get(internal_response, :completion_tokens, 0)
      }
    }
  end

  @doc """
  Convierte un chunk de streaming al formato SSE de Anthropic.
  Claude Code espera eventos SSE con tipos específicos.
  """
  def to_anthropic_stream_chunk(chunk, event_type) when is_atom(event_type) do
    data =
      case event_type do
        :start ->
          %{
            "type" => "message_start",
            "message" => %{"role" => "assistant", "usage" => %{"input_tokens" => 0}}
          }

        :content_block_start ->
          %{"type" => "content_block_start", "index" => 0, "content_block" => %{"type" => "text"}}

        :delta ->
          %{
            "type" => "content_block_delta",
            "index" => 0,
            "delta" => %{"type" => "text_delta", "text" => chunk.content}
          }

        :content_block_stop ->
          %{"type" => "content_block_stop", "index" => 0}

        :stop ->
          %{
            "type" => "message_delta",
            "delta" => %{"stop_reason" => "end_turn"},
            "usage" => %{"output_tokens" => Map.get(chunk, :tokens, 0)}
          }

        _ ->
          %{"type" => "ping"}
      end

    "event: #{event_type}\ndata: #{Jason.encode!(data)}\n\n"
  end

  @doc """
  Genera el evento de inicio de mensaje para streaming.
  """
  def stream_start_event(input_tokens \\ 0) do
    "event: message_start\ndata: #{Jason.encode!(%{"type" => "message_start", "message" => %{"id" => "msg_#{generate_id()}", "type" => "message", "role" => "assistant", "content" => [], "model" => "", "stop_reason" => nil, "usage" => %{"input_tokens" => input_tokens}}})}\n\n"
  end

  @doc """
  Genera el evento de fin de mensaje para streaming.
  """
  def stream_stop_event(_output_tokens \\ 0) do
    "event: message_stop\ndata: #{Jason.encode!(%{"type" => "message_stop"})}\n\n"
  end

  defp map_anthropic_model(nil), do: "auto"
  defp map_anthropic_model(""), do: "auto"
  defp map_anthropic_model("auto"), do: "auto"

  defp map_anthropic_model(model_name) do
    # V4.0: Buscar si hay una personalidad que use este modelo
    case ElPaso.Domain.PersonalityManager.find_by_model_name(model_name) do
      nil -> "auto"
      personality -> personality.name
    end
  end

  defp map_finish_reason(nil), do: "end_turn"
  defp map_finish_reason(:stop), do: "end_turn"
  defp map_finish_reason(:length), do: "max_tokens"
  defp map_finish_reason(_), do: "end_turn"

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  # ─── OpenAI format translators ──────────────────────────────────────────

  @doc "Convierte request OpenAI al formato interno de ElPaso."
  def from_openai(params) when is_map(params) do
    messages = Map.get(params, "messages", [])

    %InternalRequest{
      messages: messages,
      model_hint: Map.get(params, "personality") || Map.get(params, "model"),
      personality_hint: Map.get(params, "personality"),
      max_tokens: Map.get(params, "max_tokens"),
      temperature: Map.get(params, "temperature"),
      stream: Map.get(params, "stream", false)
    }
  end

  @doc "Convierte respuesta interna de ElPaso al formato OpenAI."
  def to_openai(internal_response, model_name \\ "auto") do
    used_model = Map.get(internal_response, :model_name) || model_name
    %{
      id: "chatcmpl-#{generate_id()}",
      object: "chat.completion",
      created: System.os_time(:second),
      model: used_model,
      choices: [
        %{
          index: 0,
          message: %{
            role: "assistant",
            content: internal_response.content || ""
          },
          finish_reason: map_finish_reason(internal_response.finish_reason)
        }
      ],
      usage: %{
        prompt_tokens: internal_response.prompt_tokens || 0,
        completion_tokens: internal_response.completion_tokens || 0,
        total_tokens: (internal_response.prompt_tokens || 0) + (internal_response.completion_tokens || 0)
      }
    }
  end
end
