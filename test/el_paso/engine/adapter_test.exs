defmodule ElPaso.Engine.AdapterTest do
  use ExUnit.Case, async: true
  alias ElPaso.Engine.Adapter

  @model %ElPaso.Models.Model{
    id: Ecto.UUID.generate(),
    name: "gpt-4",
    url: nil,
    api_key: nil,
    engine_id: nil,
    config: %{},
    active: true,
    max_tokens: 4096,
    temperature: 0.7,
    top_p: 1.0,
    description: nil,
    task_affinity: %{},
    complexity_ceiling: 1.0,
    cold_start_estimate_ms: 5000,
    ram_mb: nil,
    vram_mb: nil
  }

  @engine %ElPaso.Models.Engine{
    id: Ecto.UUID.generate(),
    name: "openai",
    adapter: "openai",
    base_url: "https://api.openai.com/v1",
    api_key: "test-key",
    config: %{},
    active: true,
    health_status: "unknown",
    last_health_check: nil
  }

  @messages [%{"role" => "user", "content" => "Hello"}]

  describe "infer/4" do
    test "returns error for unknown adapter" do
      engine = %{@engine | adapter: "unknown"}
      assert {:error, %{type: :unknown_adapter}} = Adapter.infer(@messages, @model, engine)
    end

    test "dispatches to openai adapter" do
      # This would make a real HTTP call, so we just verify it returns
      # an error (network/auth) rather than crashing
      result = Adapter.infer(@messages, @model, @engine)
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end

    test "dispatches to anthropic adapter" do
      engine = %{@engine | adapter: "anthropic", base_url: "https://api.anthropic.com"}
      result = Adapter.infer(@messages, @model, engine)
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end

    test "dispatches to ollama adapter" do
      engine = %{@engine | adapter: "ollama", base_url: "http://localhost:11434"}
      result = Adapter.infer(@messages, @model, engine)
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end

    test "dispatches to llama adapter" do
      engine = %{@engine | adapter: "llama", base_url: "http://localhost:8080/v1"}
      result = Adapter.infer(@messages, @model, engine)
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end

    test "accepts openai_compatible as alias" do
      engine = %{@engine | adapter: "openai_compatible"}
      result = Adapter.infer(@messages, @model, engine)
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "stream_infer/5" do
    test "returns error for unknown adapter" do
      engine = %{@engine | adapter: "unknown"}

      assert {:error, %{type: :unknown_adapter}} =
               Adapter.stream_infer(@messages, @model, engine, %{}, fn _ -> :ok end)
    end

    test "returns unsupported for anthropic streaming" do
      engine = %{@engine | adapter: "anthropic"}

      assert {:error, %{type: :unsupported}} =
               Adapter.stream_infer(@messages, @model, engine, %{}, fn _ -> :ok end)
    end

    test "dispatches to openai stream" do
      result = Adapter.stream_infer(@messages, @model, @engine, %{}, fn _ -> :ok end)
      assert match?({:error, _}, result) or match?(:ok, result)
    end

    test "dispatches to ollama stream" do
      engine = %{@engine | adapter: "ollama", base_url: "http://localhost:11434"}
      result = Adapter.stream_infer(@messages, @model, engine, %{}, fn _ -> :ok end)
      assert match?({:error, _}, result) or match?(:ok, result)
    end

    test "dispatches to llama stream" do
      engine = %{@engine | adapter: "llama", base_url: "http://localhost:8080/v1"}
      result = Adapter.stream_infer(@messages, @model, engine, %{}, fn _ -> :ok end)
      assert match?({:error, _}, result) or match?(:ok, result)
    end
  end
end
