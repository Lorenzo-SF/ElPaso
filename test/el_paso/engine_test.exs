defmodule ElPaso.EngineTest do
  @moduledoc """
  Tests para ElPaso.Engine, Response y Chunk.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Engine.{Response, Chunk}

  describe "Response struct" do
    test "se puede crear" do
      r = %Response{content: "hello", finish_reason: :stop, prompt_tokens: 10, completion_tokens: 5, latency_ms: 100}
      assert r.content == "hello"
      assert r.finish_reason == :stop
    end
  end

  describe "Chunk struct" do
    test "se puede crear" do
      c = %Chunk{content: "h", done: false, tokens: 1}
      assert c.content == "h"
      refute c.done
    end
  end
end