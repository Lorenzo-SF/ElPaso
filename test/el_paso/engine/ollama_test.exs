defmodule ElPaso.Engine.OllamaTest do
  @moduledoc """
  Tests para ElPaso.Engine.Ollama.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Engine.Ollama

  describe "new/1" do
    test "crea un adaptador" do
      adapter = Ollama.new("http://localhost:11434")
      assert adapter.base_url == "http://localhost:11434"
      assert adapter.api_key == "ollama"
    end
  end

  describe "infer/2" do
    test "devuelve respuesta simulada" do
      assert {:ok, "response from ollama"} = Ollama.infer(%{}, "prompt")
    end
  end
end
