defmodule ElPaso.Context.Schemas.MessageTest do
  use ExUnit.Case, async: true
  alias ElPaso.Context.Schemas.Message

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
        session_id: "sess-123",
        role: "user",
        content: "Hello",
        model_id: "gpt-4",
        tokens: 10
      }

      changeset = Message.changeset(%Message{}, attrs)
      assert changeset.valid?
    end

    test "invalid without required fields" do
      attrs = %{}
      changeset = Message.changeset(%Message{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).session_id
      assert "can't be blank" in errors_on(changeset).role
      assert "can't be blank" in errors_on(changeset).content
    end

    test "valid without optional fields" do
      attrs = %{
        session_id: "sess-123",
        role: "assistant",
        content: "Hi"
      }

      changeset = Message.changeset(%Message{}, attrs)
      assert changeset.valid?
    end

    test "struct has correct fields" do
      msg = %Message{}
      assert msg.__meta__ != nil
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%\{(\w+)\}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
