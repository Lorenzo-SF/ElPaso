defmodule ElPaso.Domain.AutoTunerTest do
  use ElPaso.DataCase, async: false

  alias ElPaso.Domain.AutoTuner

  setup do
    # Ensure affinity table exists
    ElPaso.Config.Loader.init_affinity_table()
    :ok
  end

  describe "start_link/1" do
    test "starts the GenServer" do
      assert {:ok, pid} = AutoTuner.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "run_now/0" do
    test "sends cast to run auto-tune" do
      assert :ok = AutoTuner.run_now()
    end
  end

  describe "revert_last/0" do
    test "returns error when no auto-tune runs exist" do
      state = %{last_run: nil, last_suggestions_applied: [], tuning?: false}
      assert {:reply, {:error, "No hay auto-tune runs para revertir"}, _state} =
               AutoTuner.handle_call(:revert_last, self(), state)
    end
  end

  describe "GenServer callbacks" do
    test "init schedules next run" do
      assert {:ok, state} = AutoTuner.init([])
      assert state.last_run == nil
      assert state.tuning? == false
      assert state.last_suggestions_applied == []
    end

    test "handle_info :run_auto_tune when already tuning" do
      state = %{tuning?: true, last_run: nil}
      assert {:noreply, ^state} = AutoTuner.handle_info(:run_auto_tune, state)
    end

    test "handle_info :run_auto_tune triggers continue" do
      state = %{tuning?: false, last_run: nil, last_suggestions_applied: []}
      assert {:noreply, new_state, {:continue, :run_auto_tune}} = AutoTuner.handle_info(:run_auto_tune, state)
      assert new_state.tuning? == true
    end

    test "handle_cast :run_auto_tune triggers continue" do
      state = %{tuning?: false, last_run: nil, last_suggestions_applied: []}
      assert {:noreply, new_state, {:continue, :run_auto_tune}} = AutoTuner.handle_cast(:run_auto_tune, state)
      assert new_state.tuning? == true
    end

    test "handle_call :revert_last with no runs" do
      state = %{last_run: nil}
      assert {:reply, {:error, "No hay auto-tune runs para revertir"}, ^state} =
               AutoTuner.handle_call(:revert_last, self(), state)
    end
  end
end
