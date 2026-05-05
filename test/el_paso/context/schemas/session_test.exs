defmodule ElPaso.Context.Schemas.SessionTest do
  use ExUnit.Case, async: true
  alias ElPaso.Context.Schemas.Session

  describe "changeset/2" do
    test "valid changeset with all fields" do
      attrs = %{
        session_id: "sess-123",
        user_id: "user-456",
        model_id: "gpt-4",
        context_mode: "transparent",
        status: "active"
      }

      changeset = Session.changeset(%Session{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with minimal fields" do
      attrs = %{session_id: "sess-123"}
      changeset = Session.changeset(%Session{}, attrs)
      assert changeset.valid?
    end

    test "has default values" do
      session = %Session{}
      assert session.context_mode == "transparent"
      assert session.status == "active"
    end

    test "struct fields exist" do
      session = %Session{}
      assert session.__meta__ != nil
      assert session.session_id == nil
    end
  end
end
