defmodule ElPaso.Domain.AutoTunerComprehensiveTest do
  use ElPaso.DataCase, async: false

  alias ElPaso.Domain.AutoTuner

  setup do
    # Ensure affinity table exists
    ElPaso.Config.Loader.init_affinity_table()

    # Create a temporary config file enabling auto-tune
    config_path = Path.join([System.user_home!(), ".config", "elpaso", "elpaso.conf"])
    File.mkdir_p!(Path.dirname(config_path))

    original_content = if File.exists?(config_path), do: File.read!(config_path), else: nil

    File.write!(config_path, """
    [routing]
    auto_tune = true
    auto_tune_min_confidence = 0.1
    auto_tune_min_decisions = 1
    auto_tune_check_interval_hours = 24
    """)

    on_exit(fn ->
      if original_content do
        File.write!(config_path, original_content)
      else
        File.rm(config_path)
      end
    end)

    :ok
  end

  describe "handle_continue with auto-tune enabled" do
    test "runs auto-tune and completes" do
      state = %{last_run: nil, last_suggestions_applied: [], tuning?: true}
      assert {:noreply, new_state} = AutoTuner.handle_continue(:run_auto_tune, state)
      assert new_state.tuning? == false
    end
  end

  describe "revert_last with auto-tune data" do
    test "reverts applied changes" do
      # First save an auto-tune run
      assert {:ok, _} = ElPaso.Context.Storage.save_auto_tune_run(%{
        applied: 1,
        at: DateTime.utc_now(),
        changes: [
          %{
            model_id: "test-model",
            task_type: "code",
            previous_affinity: 0.5,
            new_affinity: 0.8
          }
        ]
      })

      state = %{last_run: nil, last_suggestions_applied: [], tuning?: false}
      assert {:reply, {:ok, message}, _state} = AutoTuner.handle_call(:revert_last, self(), state)
      assert message =~ "1 cambios"
    end
  end
end
