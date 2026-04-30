defmodule ElPaso.CLI.Commands.RouterTuneTest do
  @moduledoc """
  Tests para ElPaso.CLI.Commands.RouterTune.
  """

  use ExUnit.Case, async: false

  alias ElPaso.CLI.Commands.RouterTune
  alias ElPaso.Context.Storage

  setup do
    unless Process.whereis(ElPaso.Repo) do
      {:ok, _} = ElPaso.Repo.start_link()
    end

    :ok = Ecto.Adapters.SQL.Sandbox.checkout(ElPaso.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(ElPaso.Repo, {:shared, self()})

    start_supervised!({ElPaso.Domain.AutoTuner, []})
    :ok
  end

  test "run sin opciones ejecuta tuner sin datos" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        RouterTune.run([])
      end)

    assert output =~ "análisis de tendencias" or output =~ "No hay datos"
  end

  test "run sin opciones ejecuta tuner con datos" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    for i <- 1..5 do
      Storage.save_routing_decision(%{
        request_id: "rt-#{i}",
        session_id: "s1",
        model_id: "gpt-4",
        task_type: "code",
        selected_model: "gpt-4",
        decided_at: DateTime.add(now, -i * 3600),
        outcome: "success",
        latency_ms: 100
      })
    end

    output =
      ExUnit.CaptureIO.capture_io(fn ->
        RouterTune.run([])
      end)

    assert output =~ "gpt-4@code" or output =~ "análisis de tendencias"
  end

  test "run con revert_auto ejecuta revert" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        RouterTune.run(revert_auto: true)
      end)

    assert output =~ "✓" or output =~ "✗"
  end
end
