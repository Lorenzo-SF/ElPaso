defmodule ElPaso.Engine.Ollama do
  @moduledoc """
  Wrapper para Ollama compatible con la API de OpenAI.

  Este módulo permite usar Ollama como motor de inferencia compatible
  con la API de OpenAI, pero con una URL base diferente.
  """

  @doc """
  Crea una nueva instancia del adaptador para Ollama.
  """
  def new(base_url) do
    %{
      base_url: base_url,
      api_key: "ollama"
    }
  end

  @doc """
  Envía una solicitud de inferencia a Ollama.
  """
  def infer(_adapter, _prompt) do
    # Implementación temporal
    {:ok, "response from ollama"}
  end
end
