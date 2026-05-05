defmodule ElPaso.HTTP.MessageNormalizer do
  @moduledoc """
  Normaliza mensajes a un formato canónico interno.

  ElPaso recibe mensajes en múltiples formatos:
    - OpenAI: %{"role" => "user", "content" => "text"}
    - Anthropic: %{"role" => "user", "content" => [%{"type" => "text", "text" => "..."}]}
    - Simplificado: %{content: "text"}
    - String keys vs atom keys

  Este módulo los normaliza todos a:
    %{role: String.t(), content: String.t()}
  """

  @doc """
  Normaliza una lista de mensajes al formato canónico.
  """
  @spec normalize(list()) :: [%{role: String.t(), content: String.t()}]
  def normalize(messages) when is_list(messages) do
    Enum.map(messages, &normalize_one/1)
  end

  @doc """
  Normaliza un solo mensaje.
  """
  def normalize_one(msg)

  # Anthropic content array format: [%{"type" => "text", "text" => "hello"}]
  def normalize_one(%{"content" => content} = msg) when is_list(content) do
    text =
      content
      |> Enum.filter(&(Map.get(&1, "type") == "text"))
      |> Enum.map_join("\n", &Map.get(&1, "text", ""))

    role = Map.get(msg, "role", "user")
    %{role: role, content: text}
  end

  def normalize_one(%{content: content} = msg) when is_list(content) do
    text =
      content
      |> Enum.filter(&(Map.get(&1, :type) == "text" or Map.get(&1, "type") == "text"))
      |> Enum.map_join("\n", &(Map.get(&1, :text) || Map.get(&1, "text") || ""))

    role = Map.get(msg, :role) || Map.get(msg, "role") || "user"
    %{role: role, content: text}
  end

  # String-keyed format (OpenAI / JSON parsed)
  def normalize_one(%{"role" => role, "content" => content}) when is_binary(content) do
    %{role: role, content: content}
  end

  # Atom-keyed format
  def normalize_one(%{role: role, content: content}) when is_binary(content) do
    %{role: role, content: content}
  end

  # Only content (no role)
  def normalize_one(%{"content" => content}) when is_binary(content) do
    %{role: "user", content: content}
  end

  def normalize_one(%{content: content}) when is_binary(content) do
    %{role: "user", content: content}
  end

  # String-only (bare text)
  def normalize_one(text) when is_binary(text) do
    %{role: "user", content: text}
  end

  # Fallback
  def normalize_one(_) do
    %{role: "user", content: ""}
  end
end
