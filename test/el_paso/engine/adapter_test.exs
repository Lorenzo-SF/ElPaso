defmodule ElPaso.Engine.AdapterTest do
  @moduledoc """
  Tests para ElPaso.Engine.Adapter.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Engine.Adapter
  alias ElPaso.Models.{Engine, Model}

  describe "openai/4" do
    test "devuelve respuesta simulada" do
      model = %Model{name: "gpt-4"}
      engine = %Engine{name: "openai-engine"}

      assert {:ok, response} =
               Adapter.openai([%{role: "user", content: "Hola"}], model, engine, %{})

      assert response.model == "gpt-4"
      assert response.engine == "openai-engine"
      assert response.response == "Respuesta simulada desde OpenAI"
    end
  end

  describe "anthropic/4" do
    test "devuelve respuesta simulada" do
      model = %Model{name: "claude-3"}
      engine = %Engine{name: "anthropic-engine"}

      assert {:ok, response} =
               Adapter.anthropic([%{role: "user", content: "Hola"}], model, engine, %{})

      assert response.model == "claude-3"
      assert response.response == "Respuesta simulada desde Anthropic"
    end
  end

  describe "ollama/4" do
    test "devuelve respuesta simulada" do
      model = %Model{name: "llama2"}
      engine = %Engine{name: "ollama-engine"}

      assert {:ok, response} =
               Adapter.ollama([%{role: "user", content: "Hola"}], model, engine, %{})

      assert response.model == "llama2"
      assert response.response == "Respuesta simulada desde Ollama"
    end
  end

  describe "llama_cpp/4" do
    test "devuelve respuesta simulada" do
      model = %Model{name: "mistral"}
      engine = %Engine{name: "llama-cpp-engine"}

      assert {:ok, response} =
               Adapter.llama_cpp([%{role: "user", content: "Hola"}], model, engine, %{})

      assert response.model == "mistral"
      assert response.response == "Respuesta simulada desde llama.cpp"
    end
  end

  describe "stream_openai/4" do
    test "devuelve respuesta streaming simulada" do
      model = %Model{name: "gpt-4"}
      engine = %Engine{name: "openai-engine"}

      assert {:ok, response} =
               Adapter.stream_openai([%{role: "user", content: "Hola"}], model, engine, %{})

      assert response.model == "gpt-4"
      assert response.response == "Respuesta simulada streaming desde OpenAI"
    end
  end

  describe "stream_anthropic/4" do
    test "devuelve respuesta streaming simulada" do
      model = %Model{name: "claude-3"}
      engine = %Engine{name: "anthropic-engine"}

      assert {:ok, response} =
               Adapter.stream_anthropic([%{role: "user", content: "Hola"}], model, engine, %{})

      assert response.model == "claude-3"
      assert response.response == "Respuesta simulada streaming desde Anthropic"
    end
  end

  describe "stream_ollama/4" do
    test "devuelve respuesta streaming simulada" do
      model = %Model{name: "llama2"}
      engine = %Engine{name: "ollama-engine"}

      assert {:ok, response} =
               Adapter.stream_ollama([%{role: "user", content: "Hola"}], model, engine, %{})

      assert response.model == "llama2"
      assert response.response == "Respuesta simulada streaming desde Ollama"
    end
  end

  describe "stream_llama_cpp/4" do
    test "devuelve respuesta streaming simulada" do
      model = %Model{name: "mistral"}
      engine = %Engine{name: "llama-cpp-engine"}

      assert {:ok, response} =
               Adapter.stream_llama_cpp([%{role: "user", content: "Hola"}], model, engine, %{})

      assert response.model == "mistral"
      assert response.response == "Respuesta simulada streaming desde llama.cpp"
    end
  end
end
