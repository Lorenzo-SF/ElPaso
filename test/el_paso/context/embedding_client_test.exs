defmodule ElPaso.Context.EmbeddingClientTest do
  @moduledoc """
  Tests para ElPaso.Context.EmbeddingClient.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Context.EmbeddingClient

  describe "new/1" do
    test "crea un cliente" do
      client = EmbeddingClient.new("text-embedding-3")
      assert client.model_id == "text-embedding-3"
      assert client.engine_type == "ollama"
      assert client.timeout == 30
    end
  end

  describe "generate_embeddings/2" do
    test "devuelve lista vacía" do
      client = EmbeddingClient.new("model")
      assert {:ok, []} = EmbeddingClient.generate_embeddings(client, ["hello", "world"])
    end
  end

  describe "generate_embedding/2" do
    test "devuelve lista vacía" do
      client = EmbeddingClient.new("model")
      assert {:ok, []} = EmbeddingClient.generate_embedding(client, "hello")
    end
  end

  describe "rebuild_embeddings/1" do
    test "devuelve :ok" do
      assert :ok = EmbeddingClient.rebuild_embeddings("sess-1")
    end
  end

  describe "ping/0" do
    test "devuelve mensaje de disponibilidad" do
      assert {:ok, msg} = EmbeddingClient.ping()
      assert msg =~ "available"
    end
  end
end