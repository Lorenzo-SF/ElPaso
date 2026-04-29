defmodule ElPaso.Context.TokenizerTest do
  @moduledoc """
  Tests para ElPaso.Context.Tokenizer.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Context.Tokenizer

  describe "count/2" do
    test "cuenta tokens de un texto" do
      assert {:fallback, n} = Tokenizer.count("Hola mundo", "gpt-4")
      assert is_integer(n)
      assert n > 0
    end
  end

  describe "register/2" do
    test "registra un tokenizador" do
      assert :ok = Tokenizer.register("gpt-4", %{backend: :estimate})
    end
  end

  describe "info/1" do
    test "devuelve información del backend" do
      info = Tokenizer.info("gpt-4")
      assert info.backend == :estimate
      assert info.registered_at != nil
    end
  end

  describe "list/0" do
    test "lista tokenizadores registrados" do
      assert is_list(Tokenizer.list())
    end
  end
end
