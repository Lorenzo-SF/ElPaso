defmodule ElPaso.Engine.HTTPClient do
  @moduledoc """
  Cliente HTTP universal para engines de inferencia via Finch.

  Soporta los principales adapters: openai, anthropic, ollama, llama.
  """
  require Logger

  # ── Safe Logging ────────────────────────────────────────────
  # Redacta API keys y secrets de mensajes de log
  defp log_safe_error(msg) do
    Logger.error(fn -> sanitize_for_log(msg) end)
  end

  defp sanitize_for_log(term) when is_binary(term), do: term

  defp sanitize_for_log(%{api_key: _} = map) do
    Map.put(map, :api_key, "[REDACTED]")
  end

  defp sanitize_for_log(%{config: config} = map) when is_map(config) do
    sanitized_config = Map.drop(config || %{}, [:api_key])
    Map.put(map, :config, sanitized_config)
  end

  defp sanitize_for_log(term), do: inspect(term)

  @finch ElPaso.Finch

  # Timeout por defecto: 120 segundos
  @default_timeout 120_000

  @type result :: {:ok, map()} | {:error, term()}

  # ---------------------------------------------------------------------------
  # OpenAI-compatible API (/v1/chat/completions)
  # ---------------------------------------------------------------------------

  @doc """
  Ejecuta inferencia via OpenAI-compatible API.

  ## Parameters
    - base_url: URL base del servidor (ej: "https://api.openai.com/v1" o "http://localhost:11434/v1")
    - model: nombre del modelo
    - messages: lista de mensajes [{role, content}]
    - opts: keyword con :api_key, :temperature, :max_tokens, :top_p, :timeout
  """
  @spec openai_compatible(String.t(), String.t(), [map()], keyword()) :: result()
  def openai_compatible(base_url, model, messages, opts \\ []) do
    api_key = Keyword.get(opts, :api_key, "")
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 4096)
    top_p = Keyword.get(opts, :top_p, 1.0)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    body = %{
      model: model,
      messages: messages,
      temperature: temperature,
      max_tokens: max_tokens,
      top_p: top_p
    }

    headers = [
      {"content-type", "application/json"},
      {"authorization", "Bearer #{api_key}"}
    ]

    url = "#{String.trim(base_url, "/")}/chat/completions"

    case request(:post, url, headers, body, timeout) do
      {:ok, %{"choices" => [%{"message" => message, "finish_reason" => finish}]} = response} ->
        resp_usage = Map.get(response, "usage", %{})

        {:ok,
         %{
           content: message["content"],
           finish_reason: map_finish_reason(finish),
           prompt_tokens: Map.get(resp_usage, "prompt_tokens", 0) |> safe_int(),
           completion_tokens: Map.get(resp_usage, "completion_tokens", 0) |> safe_int()
         }}

      {:ok, %{"error" => error}} ->
        {:error, %{type: :api_error, message: error["message"] || inspect(error)}}

      {:ok, other} ->
        {:error, %{type: :unexpected_response, data: other}}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Anthropic API (/v1/messages)
  # ---------------------------------------------------------------------------

  @doc """
  Ejecuta inferencia via Anthropic API (messages endpoint).

  ## Parameters
    - base_url: URL base (ej: "https://api.anthropic.com")
    - model: nombre del modelo (ej: "claude-3-sonnet-20240229")
    - messages: lista de mensajes [{role, content}]
    - opts: :api_key, :max_tokens, :temperature, :timeout
  """
  @spec anthropic(String.t(), String.t(), [map()], keyword()) :: result()
  def anthropic(base_url, model, messages, opts \\ []) do
    api_key = Keyword.get(opts, :api_key, "")
    max_tokens = Keyword.get(opts, :max_tokens, 1024)
    temperature = Keyword.get(opts, :temperature, 0.7)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    # Extraer mensaje de sistema y mensajes de conversación
    {system_msg, conversation} = extract_system_message(messages)

    body =
      %{
        model: model,
        messages: transform_messages_for_anthropic(conversation),
        max_tokens: max_tokens,
        temperature: temperature
      }
      |> maybe_add_system(system_msg)

    headers = [
      {"content-type", "application/json"},
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"}
    ]

    url = "#{String.trim(base_url, "/")}/v1/messages"

    case request(:post, url, headers, body, timeout) do
      {:ok, %{"content" => [%{"text" => text}], "stop_reason" => stop} = response} ->
        resp_usage = Map.get(response, "usage", %{})

        {:ok,
         %{
           content: text,
           finish_reason: map_anthropic_reason(stop),
           prompt_tokens: Map.get(resp_usage, "input_tokens", 0) |> safe_int(),
           completion_tokens: Map.get(resp_usage, "output_tokens", 0) |> safe_int()
         }}

      {:ok, %{"error" => error}} ->
        {:error, %{type: :api_error, message: error["type"] || inspect(error)}}

      {:ok, other} ->
        {:error, %{type: :unexpected_response, data: other}}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Ollama API (/api/chat)
  # ---------------------------------------------------------------------------

  @doc """
  Ejecuta inferencia via Ollama API (local).

  ## Parameters
    - base_url: URL base de Ollama (ej: "http://localhost:11434")
    - model: nombre del modelo (ej: "llama3")
    - messages: lista de mensajes
    - opts: :timeout
  """
  @spec ollama(String.t(), String.t(), [map()], keyword()) :: result()
  def ollama(base_url, model, messages, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    body = %{
      model: model,
      messages: messages,
      stream: false
    }

    headers = [{"content-type", "application/json"}]
    url = "#{String.trim(base_url, "/")}/api/chat"

    case request(:post, url, headers, body, timeout) do
      {:ok, %{"message" => %{"content" => content}, "done" => true}} ->
        {:ok,
         %{
           content: content,
           finish_reason: :stop,
           prompt_tokens: 0,
           completion_tokens: 0
         }}

      {:ok, %{"error" => error}} ->
        {:error, %{type: :api_error, message: error}}

      {:ok, other} ->
        {:error, %{type: :unexpected_response, data: other}}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # llama.cpp (compatible con OpenAI)
  # ---------------------------------------------------------------------------

  @doc """
  Ejecuta inferencia via servidor llama.cpp (compatible con OpenAI).

  Usa el endpoint /v1/chat/completions que es compatible con la mayoria
  de servidores local como text-generation-webui, LM Studio, etc.
  """
  @spec llama_cpp(String.t(), String.t(), [map()], keyword()) :: result()
  def llama_cpp(base_url, model, messages, opts \\ []) do
    # llama.cpp es compatible con OpenAI
    openai_compatible(base_url, model, messages, opts)
  end

  # ---------------------------------------------------------------------------
  # Streaming
  # ---------------------------------------------------------------------------

  @doc """
  Ejecuta inferencia con streaming. Itera sobre los chunks via callback.
  """
  @spec stream_openai(String.t(), String.t(), [map()], keyword(), (map() -> :ok)) ::
          :ok | {:error, term()}
  def stream_openai(base_url, model, messages, opts \\ [], callback) do
    api_key = Keyword.get(opts, :api_key, "")
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 4096)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    body = %{
      model: model,
      messages: messages,
      temperature: temperature,
      max_tokens: max_tokens,
      stream: true
    }

    headers = [
      {"content-type", "application/json"},
      {"authorization", "Bearer #{api_key}"}
    ]

    url = "#{String.trim(base_url, "/")}/chat/completions"

    stream_request(:post, url, headers, body, timeout, fn chunk ->
      # OpenAI streaming: data: {"choices":[{"delta":{"content":"..."}}]}
      case chunk do
        <<"data: ", rest::binary>> ->
          data = String.trim(rest)

          if data != "[DONE]" do
            case Jason.decode(data) do
              {:ok, %{"choices" => [%{"delta" => %{"content" => content}}]}}
              when is_binary(content) ->
                callback.(%{content: content})
                :ok

              _ ->
                :ok
            end
          end

        _ ->
          :ok
      end
    end)
  end

  @spec stream_ollama(String.t(), String.t(), [map()], keyword(), (map() -> :ok)) ::
          :ok | {:error, term()}
  def stream_ollama(base_url, model, messages, opts \\ [], callback) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    body = %{
      model: model,
      messages: messages,
      stream: true
    }

    headers = [{"content-type", "application/json"}]
    url = "#{String.trim(base_url, "/")}/api/chat"

    stream_request(:post, url, headers, body, timeout, fn chunk ->
      # Ollama streaming: {"message":{"content":"..."},"done":false}
      case Jason.decode(chunk) do
        {:ok, %{"message" => %{"content" => content}}} ->
          callback.(%{content: content})
          :ok

        _ ->
          :ok
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp request(method, url, headers, body, timeout) do
    encoded_body = Jason.encode!(body)

    request = Finch.build(method, url, headers, encoded_body)

    case Finch.request(request, @finch, receive_timeout: timeout) do
      {:ok, %{status: status, headers: _resp_headers, body: body}}
      when status >= 200 and status < 300 ->
        case Jason.decode(body) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, _} -> {:ok, %{raw: body}}
        end

      {:ok, %{status: status, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"error" => error}} -> {:error, %{status: status, error: error}}
          {:ok, parsed} -> {:error, %{status: status, data: parsed}}
          {:error, _} -> {:error, %{status: status, body: body}}
        end

      {:error, reason} ->
        log_safe_error("[ElPaso.Engine.HTTPClient] Request failed: #{sanitize_for_log(reason)}")
        {:error, %{type: :network_error, reason: sanitize_for_log(reason)}}
    end
  end

  defp stream_request(method, url, headers, body, timeout, chunk_callback) do
    encoded_body = Jason.encode!(body)
    request = Finch.build(method, url, headers, encoded_body)

    case Finch.stream(request, @finch, chunk_callback,
           receive_timeout: timeout || @default_timeout
         ) do
      :ok ->
        :ok

      {:error, reason} ->
        log_safe_error("[ElPaso.Engine.HTTPClient] Stream failed: #{sanitize_for_log(reason)}")
        {:error, sanitize_for_log(reason)}
    end
  end

  # Extrae el mensaje con role: "system" y lo separa del resto
  defp extract_system_message(messages) do
    system =
      Enum.find(messages, &(Map.get(&1, "role") == "system" or Map.get(&1, :role) == :system))

    conversation =
      Enum.reject(messages, &(Map.get(&1, "role") == "system" or Map.get(&1, :role) == :system))

    {system, conversation}
  end

  defp maybe_add_system(body, nil), do: body
  defp maybe_add_system(body, %{"content" => content}), do: Map.put(body, :system, content)
  defp maybe_add_system(body, %{content: content}), do: Map.put(body, :system, content)

  defp transform_messages_for_anthropic(messages) do
    Enum.map(messages, fn
      %{"role" => role, "content" => content} when role in ["user", "assistant"] ->
        %{role: role, content: content}

      %{role: role, content: content} when role in [:user, :assistant] ->
        %{role: Atom.to_string(role), content: content}

      _ ->
        # No debería llegar aquí porque los system ya se extrajeron
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp map_finish_reason("stop"), do: :stop
  defp map_finish_reason("length"), do: :length
  defp map_finish_reason("tool_calls"), do: :stop
  defp map_finish_reason(nil), do: :stop
  defp map_finish_reason(_), do: :stop

  defp map_anthropic_reason("end_turn"), do: :stop
  defp map_anthropic_reason("max_tokens"), do: :length
  defp map_anthropic_reason("stop_sequence"), do: :stop
  defp map_anthropic_reason(_), do: :stop

  defp safe_int(nil), do: 0
  defp safe_int(n) when is_integer(n), do: n
  defp safe_int(n) when is_float(n), do: round(n)
  defp safe_int(_), do: 0
end
