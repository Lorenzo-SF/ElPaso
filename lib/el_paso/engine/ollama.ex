defmodule ElPaso.Engine.Ollama do
  @moduledoc """
  Wrapper sobre OpenAI adapter con base_url diferente para Ollama.
  
  Este módulo permite usar Ollama como motor de inferencia compatible 
  con la API de OpenAI, pero con una URL base diferente.
  """

  alias ElPaso.Engine.OpenAIAdapter

  @doc """
  Crea una nueva instancia del adaptador para Ollama.
  """
  def new(base_url) do
    %{
      adapter: OpenAIAdapter,
      base_url: base_url,
      api_key: "ollama"  # Ollama no requiere API key
    }
  end

  @doc """
  Envía una solicitud de inferencia a Ollama.
  """
  def infer(adapter, prompt) do
    OpenAIAdapter.infer(adapter, prompt)
  end
end