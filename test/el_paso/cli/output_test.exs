defmodule ElPaso.CLI.OutputTest do
  use ExUnit.Case, async: true
  alias ElPaso.CLI.Output

  describe "semantic messages" do
    test "success/1 prints a message" do
      assert Output.success("test") == :ok
    end

    test "error/1 prints a message" do
      assert Output.error("test") == :ok
    end

    test "info/1 prints a message" do
      assert Output.info("test") == :ok
    end

    test "warning/1 prints a message" do
      assert Output.warning("test") == :ok
    end

    test "debug/1 prints a message" do
      assert Output.debug("test") == :ok
    end

    test "critical/1 prints a message" do
      assert Output.critical("test") == :ok
    end

    test "alert/1 prints a message" do
      assert Output.alert("test") == :ok
    end

    test "emergency/1 prints a message" do
      assert Output.emergency("test") == :ok
    end
  end

  describe "section/2" do
    test "prints a header with default color" do
      assert Output.section("Title") == :ok
    end

    test "accepts custom color" do
      assert Output.section("Title", color: {255, 0, 0}) == :ok
    end

    test "accepts subtitle" do
      assert Output.section("Title", subtitle: "Subtitle") == :ok
    end
  end

  describe "divider/2" do
    test "prints a separator without text" do
      assert Output.divider() == :ok
    end

    test "prints a separator with text" do
      assert Output.divider("Section") == :ok
    end

    test "accepts custom options" do
      assert Output.divider("Section", width: 40, color: {255, 0, 0}) == :ok
    end
  end

  describe "data_table/1" do
    test "accepts keyword list" do
      assert Output.data_table(headers: ["A"], rows: [["1"]]) == :ok
    end

    test "accepts empty keyword list" do
      assert Output.data_table([]) == :ok
    end
  end

  describe "data_table/2" do
    test "accepts headers and rows" do
      assert Output.data_table(["Name", "Status"], [["test", "ok"]]) == :ok
    end
  end

  describe "data_table/3" do
    test "accepts headers, rows and opts" do
      assert Output.data_table(["Name"], [["test"]], table_border: :single) == :ok
    end
  end

  describe "alert_box/2" do
    test "prints info box by default" do
      assert Output.alert_box("Message") == :ok
    end

    test "prints success box" do
      assert Output.alert_box("Message", type: :success) == :ok
    end

    test "prints error box" do
      assert Output.alert_box("Message", type: :error) == :ok
    end

    test "prints warning box" do
      assert Output.alert_box("Message", type: :warning) == :ok
    end

    test "accepts list of strings" do
      assert Output.alert_box(["Line 1", "Line 2"]) == :ok
    end
  end

  describe "json_data/2" do
    test "prints JSON data" do
      assert Output.json_data(%{key: "value"}) == :ok
    end
  end

  describe "breadcrumbs/2" do
    test "prints breadcrumb trail" do
      assert Output.breadcrumbs(["home", "models"]) == :ok
    end
  end

  describe "progress_bar/3" do
    test "prints a progress bar" do
      assert Output.progress_bar(75) == :ok
    end

    test "prints with custom max" do
      assert Output.progress_bar(50, 200) == :ok
    end

    test "prints with label" do
      assert Output.progress_bar(75, 100, label: "Progress") == :ok
    end
  end
end
