defmodule ElPaso.Engine.ChatTemplateTest do
  @moduledoc """
  Tests para ElPaso.Engine.ChatTemplate.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Engine.ChatTemplate

  describe "format_message/1" do
    test "formatea un mensaje" do
      assert %{role: "user", content: "hola"} =
               ChatTemplate.format_message(%{role: "user", content: "hola"})
    end
  end

  describe "format_messages/1" do
    test "formatea una lista de mensajes" do
      msgs = [%{role: "user", content: "hola"}]
      assert [%{role: "user", content: "hola"}] = ChatTemplate.format_messages(msgs)
    end
  end

  describe "build_prompt/2" do
    test "construye prompt con system y user" do
      prompt = ChatTemplate.build_prompt("Eres útil.", "Hola")
      assert length(prompt) == 2
      assert hd(prompt).role == "system"
    end
  end
end
