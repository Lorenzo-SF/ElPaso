defmodule ElPaso.Engine.ChatTemplate do
  @moduledoc """
  Formatea mensajes según el template del modelo.

  Este módulo asegura que los mensajes se formateen correctamente para ser consumidos
  por los motores de inferencia compatibles con la API de OpenAI.
  """

  @doc """
  Formatea un mensaje para el modelo.
  """
  def format_message(%{role: role, content: content}) do
    %{
      role: role,
      content: content
    }
  end

  @doc """
  Formatea una lista de mensajes.
  """
  def format_messages(messages) do
    Enum.map(messages, &format_message/1)
  end

  @doc """
  Genera un prompt completo para el modelo.
  """
  def build_prompt(system_prompt, user_prompt) do
    [
      %{role: "system", content: system_prompt},
      %{role: "user", content: user_prompt}
    ]
  end
end
