defmodule ElPaso.HTTP.AnthropicProxyTest do
  @moduledoc """
  Tests para ElPaso.HTTP.AnthropicProxy.
  """

  use ExUnit.Case, async: true

  alias ElPaso.HTTP.AnthropicProxy

  describe "from_anthropic/1" do
    test "convierte params anthropic" do
      req =
        AnthropicProxy.from_anthropic(%{"messages" => [%{"role" => "user", "content" => "hola"}]})

      assert req.messages == [%{"role" => "user", "content" => "hola"}]
      assert req.stream == false
    end
  end

  describe "to_anthropic/2" do
    test "convierte respuesta interna" do
      internal = %AnthropicProxy.InternalRequest{
        content: "respuesta",
        prompt_tokens: 10,
        completion_tokens: 5,
        finish_reason: :stop
      }

      resp = AnthropicProxy.to_anthropic(internal, "claude-3")
      assert resp["model"] == "claude-3"
      assert resp["stop_reason"] == "end_turn"
    end

    test "convierte map genérico" do
      resp = AnthropicProxy.to_anthropic(%{"content" => "hola"}, "claude-3")
      assert resp["model"] == "claude-3"
    end
  end

  describe "to_anthropic_stream_chunk/2" do
    test "genera eventos SSE" do
      chunk = %{content: "h", tokens: 1}
      assert AnthropicProxy.to_anthropic_stream_chunk(chunk, :delta) =~ "content_block_delta"
      assert AnthropicProxy.to_anthropic_stream_chunk(chunk, :start) =~ "message_start"
      assert AnthropicProxy.to_anthropic_stream_chunk(chunk, :stop) =~ "message_delta"
      assert AnthropicProxy.to_anthropic_stream_chunk(chunk, :unknown) =~ "ping"
    end
  end

  describe "stream_start_event/1" do
    test "genera evento de inicio" do
      assert AnthropicProxy.stream_start_event(10) =~ "message_start"
    end
  end

  describe "stream_stop_event/1" do
    test "genera evento de fin" do
      assert AnthropicProxy.stream_stop_event(5) =~ "message_stop"
    end
  end
end
