defmodule ElPaso.Engine.Plugin.Echo do
  @moduledoc """
  Echo engine plugin - simple plugin de ejemplo para pruebas.

  Este engine simplemente devuelve el prompt recibido como respuesta.
  Útil para testing y como template para otros plugins.
  """

  use ElPaso.Engine

  @impl true
  def name, do: :echo

  @impl true
  def type, do: :local_process

  @impl true
  def infer(prompt, _params, _config) do
    # Extraer contenido del prompt
    content = extract_content(prompt)

    {:ok,
     %ElPaso.Engine.Response{
       content: "Echo: #{content}",
       finish_reason: :stop,
       prompt_tokens: count_tokens(content),
       completion_tokens: count_tokens(content),
       latency_ms: 1
     }}
  end

  @impl true
  def stream(prompt, _params, _config, chunk_callback) do
    content = extract_content(prompt)
    words = String.split(content, " ")

    Enum.each(words, fn word ->
      chunk_callback.(%ElPaso.Engine.Chunk{
        content: word <> " ",
        done: false,
        tokens: nil
      })
    end)

    # Enviar chunk final
    chunk_callback.(%ElPaso.Engine.Chunk{
      content: "",
      done: true,
      tokens: count_tokens(content)
    })

    :ok
  end

  @impl true
  def prepare_prefix(prefix, _config) do
    # No necesita preparación especial
    prefix
  end

  @impl true
  def health_check(_config) do
    # Siempre disponible
    :ok
  end

  @impl true
  def format_messages(messages, _context_spec) do
    # Formatear como texto simple
    Enum.map_join(messages, "\n", fn msg ->
      role = Map.get(msg, :role, "user")
      content = Map.get(msg, :content, "")
      "[#{role}]: #{content}"
    end)
  end

  # Funciones auxiliares

defp extract_content(prompt) do
    case prompt do
      %{system: system, messages: messages} ->
        system_content = if system, do: "[System]: #{system}\n", else: ""

        user_content =
          messages
          |> List.first()
          |> Map.get(:content, "")

        system_content <> user_content

      %{messages: messages} ->
        messages
        |> Enum.filter(fn m -> m.role == "user" end)
        |> List.first()
        |> Map.get(:content, "")

      _ when is_binary(prompt) ->
        prompt
    end
  end

  defp count_tokens(text) when is_binary(text) do
    # Estimación simple: ~4 caracteres por token
    div(String.length(text), 4)
  end

  defp count_tokens(_), do: 0
end
