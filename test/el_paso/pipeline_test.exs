defmodule ElPaso.PipelineTest do
  @moduledoc """
  Tests para ElPaso.Pipeline.
  """

  use ElPaso.DataCase, async: true

  alias ElPaso.Pipeline
  alias ElPaso.Domain.ModelManager
  alias ElPaso.Models.{Engine, Model}

  setup do
    {:ok, engine} =
      ElPaso.Repo.insert(%Engine{
        name: "pipeline-engine",
        adapter: "ollama",
        base_url: "http://localhost:11434"
      })

    {:ok, model} =
      ModelManager.create_model(%{name: "llama2-test", engine_id: engine.id, active: true})

    %{engine: engine, model: model}
  end

  describe "execute_inference/6" do
    test "ejecuta inferencia con adapter openai" do
      model = %Model{name: "gpt-4"}
      engine = %Engine{name: "openai-engine", adapter: "openai"}

      assert {:ok, response} =
               Pipeline.execute_inference(
                 "req-1",
                 "sess-1",
                 [%{role: "user", content: "Hola"}],
                 model,
                 engine,
                 %{}
               )

      assert response.model == "gpt-4"
    end

    test "ejecuta inferencia con adapter ollama" do
      model = %Model{name: "llama2"}
      engine = %Engine{name: "ollama-engine", adapter: "ollama"}

      assert {:ok, response} =
               Pipeline.execute_inference(
                 "req-2",
                 "sess-2",
                 [%{role: "user", content: "Hola"}],
                 model,
                 engine,
                 %{}
               )

      assert response.model == "llama2"
    end

    test "devuelve error para adapter desconocido" do
      model = %Model{name: "unknown-model"}
      engine = %Engine{name: "unknown-engine", adapter: "unknown"}

      assert {:error, msg} =
               Pipeline.execute_inference(
                 "req-3",
                 "sess-3",
                 [%{role: "user", content: "Hola"}],
                 model,
                 engine,
                 %{}
               )

      assert msg =~ "no soportado"
    end
  end

  describe "stream_inference/6" do
    test "ejecuta streaming con adapter anthropic" do
      model = %Model{name: "claude-3"}
      engine = %Engine{name: "anthropic-engine", adapter: "anthropic"}

      assert {:ok, response} =
               Pipeline.stream_inference(
                 "req-4",
                 "sess-4",
                 [%{role: "user", content: "Hola"}],
                 model,
                 engine,
                 %{}
               )

      assert response.model == "claude-3"
    end

    test "devuelve error para adapter desconocido en streaming" do
      model = %Model{name: "unknown-model2"}
      engine = %Engine{name: "unknown-engine2", adapter: "unknown2"}

      assert {:error, msg} =
               Pipeline.stream_inference(
                 "req-5",
                 "sess-5",
                 [%{role: "user", content: "Hola"}],
                 model,
                 engine,
                 %{}
               )

      assert msg =~ "no soportado"
    end
  end

  describe "process_request/4" do
    test "procesa un request completo", %{engine: _engine, model: _model} do
      assert {:ok, response} =
               Pipeline.process_request(
                 "req-6",
                 "sess-6",
                 [%{role: "user", content: "Hola"}],
                 %{}
               )

      assert is_map(response)
      assert response.model == "llama2-test"
    end
  end

  describe "stream_request/4" do
    test "procesa un request de streaming", %{engine: _engine, model: _model} do
      assert {:ok, response} =
               Pipeline.stream_request(
                 "req-7",
                 "sess-7",
                 [%{role: "user", content: "Hola"}],
                 %{}
               )

      assert is_map(response)
    end
  end
end
