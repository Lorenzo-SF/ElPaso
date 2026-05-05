defmodule ElPaso.Models.AutoTuneRunTest do
  use ExUnit.Case, async: true
  alias ElPaso.Models.AutoTuneRun

  describe "changeset/2" do
    test "valid changeset" do
      attrs = %{applied: 1, changes: [%{"key" => "value"}]}
      changeset = AutoTuneRun.changeset(%AutoTuneRun{}, attrs)
      assert changeset.valid?
    end

    test "valid with empty attrs" do
      changeset = AutoTuneRun.changeset(%AutoTuneRun{}, %{})
      assert changeset.valid?
    end

    test "struct has correct fields" do
      run = %AutoTuneRun{}
      assert run.__meta__ != nil
    end
  end
end
