defmodule ElPaso.Context.Schemas.ConversationSummaryTest do
  use ExUnit.Case, async: true
  alias ElPaso.Context.Schemas.ConversationSummary

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
        session_id: "sess-123",
        summary: "This is a summary",
        summary_tokens: 100,
        window_start: DateTime.utc_now(),
        window_end: DateTime.utc_now()
      }

      changeset = ConversationSummary.changeset(%ConversationSummary{}, attrs)
      assert changeset.valid?
    end

    test "invalid without required fields" do
      attrs = %{}
      changeset = ConversationSummary.changeset(%ConversationSummary{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).session_id
      assert "can't be blank" in errors_on(changeset).summary
    end

    test "invalid without session_id" do
      attrs = %{summary: "test"}
      changeset = ConversationSummary.changeset(%ConversationSummary{}, attrs)
      refute changeset.valid?
    end

    test "struct fields exist" do
      summary = %ConversationSummary{}
      assert summary.__meta__ != nil
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
