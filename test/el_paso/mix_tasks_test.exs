defmodule ElPaso.MixTasksTest do
  @moduledoc """
  Smoke tests para Mix tasks de ElPaso.
  """

  use ElPaso.DataCase, async: false

  alias ElPaso.Models.Engine
  alias ElPaso.Models.Model

  setup do
    {:ok, engine} =
      ElPaso.Repo.insert(%Engine{
        name: "mix-engine",
        adapter: "ollama",
        base_url: "http://localhost:11434"
      })

    %{engine: engine}
  end

  defp run_task(name, args \\ []) do
    Mix.Task.reenable(name)

    ExUnit.CaptureIO.capture_io(fn ->
      Mix.Task.run(name, args)
    end)
  end

  test "elpaso.init" do
    run_task("elpaso.init", [])
  end

  # Engine tasks
  test "elpaso.engine sin args" do
    run_task("elpaso.engine", [])
  end

  test "elpaso.engine list" do
    run_task("elpaso.engine", ["list"])
  end

  test "elpaso.engine add con args válidos" do
    run_task("elpaso.engine", [
      "add",
      "name=add-test",
      "adapter=ollama",
      "base_url=http://localhost:11434"
    ])
  end

  test "elpaso.engine add sin args completos" do
    run_task("elpaso.engine", ["add", "name=only-name"])
  end

  test "elpaso.engine remove con nombre existente", %{engine: engine} do
    run_task("elpaso.engine", ["remove", engine.name])
  end

  test "elpaso.engine remove con nombre no existente" do
    run_task("elpaso.engine", ["remove", "nonexistent"])
  end

  test "elpaso.engine test con nombre existente", %{engine: engine} do
    run_task("elpaso.engine", ["test", engine.name])
  end

  test "elpaso.engine test con nombre no existente" do
    run_task("elpaso.engine", ["test", "nonexistent"])
  end

  # Model tasks
  test "elpaso.model sin args" do
    run_task("elpaso.model", [])
  end

  test "elpaso.model list" do
    run_task("elpaso.model", ["list"])
  end

  test "elpaso.model add con args válidos", %{engine: engine} do
    run_task("elpaso.model", ["add", "name=m1", "engine=#{engine.name}", "url=http://x"])
  end

  test "elpaso.model add con engine no existente" do
    run_task("elpaso.model", ["add", "name=m1", "engine=nonexistent", "url=http://x"])
  end

  test "elpaso.model add sin args completos" do
    run_task("elpaso.model", ["add", "name=only-name"])
  end

  test "elpaso.model remove con nombre existente", %{engine: engine} do
    {:ok, model} =
      ElPaso.Repo.insert(%Model{name: "remove-model", engine_id: engine.id, url: "http://x"})

    run_task("elpaso.model", ["remove", model.name])
  end

  test "elpaso.model remove con nombre no existente" do
    run_task("elpaso.model", ["remove", "nonexistent"])
  end

  test "elpaso.model start con nombre existente", %{engine: engine} do
    {:ok, model} =
      ElPaso.Repo.insert(%Model{name: "start-model", engine_id: engine.id, url: "http://x"})

    run_task("elpaso.model", ["start", model.name])
  end

  test "elpaso.model start con nombre no existente" do
    run_task("elpaso.model", ["start", "nonexistent"])
  end

  test "elpaso.model stop con nombre existente", %{engine: engine} do
    {:ok, model} =
      ElPaso.Repo.insert(%Model{name: "stop-model", engine_id: engine.id, url: "http://x"})

    run_task("elpaso.model", ["stop", model.name])
  end

  test "elpaso.model stop con nombre no existente" do
    run_task("elpaso.model", ["stop", "nonexistent"])
  end

  # Personality tasks
  test "elpaso.personality sin args" do
    run_task("elpaso.personality", [])
  end

  test "elpaso.personality list" do
    run_task("elpaso.personality", ["list"])
  end

  test "elpaso.personality add con args" do
    run_task("elpaso.personality", ["add", "name=per1", "system_prompt=Hola"])
  end

  test "elpaso.personality remove con nombre no existente" do
    run_task("elpaso.personality", ["remove", "nonexistent"])
  end

  test "elpaso.personality show con nombre no existente" do
    run_task("elpaso.personality", ["show", "nonexistent"])
  end

  # Sub-tasks engine
  test "elpaso.engine.list" do
    run_task("elpaso.engine.list", [])
  end

  test "elpaso.engine.remove sin args" do
    run_task("elpaso.engine.remove", [])
  end

  test "elpaso.engine.test sin args" do
    run_task("elpaso.engine.test", [])
  end

  # Sub-tasks model
  test "elpaso.model.list" do
    run_task("elpaso.model.list", [])
  end

  test "elpaso.model.remove sin args" do
    run_task("elpaso.model.remove", [])
  end

  test "elpaso.model.start sin args" do
    run_task("elpaso.model.start", [])
  end

  test "elpaso.model.stop sin args" do
    run_task("elpaso.model.stop", [])
  end
end
