defmodule ElPaso.Domain.AutoTuner do
  @moduledoc """
  GenServer para auto-tuning periódico del router.
  
  Se ejecuta cada 24 horas (configurable) y aplica automáticamente
  sugerencias de alta confianza.
  """

  use GenServer
  require Logger

  alias ElPaso.Config
  alias ElPaso.Domain.RouterAnalyzer
  alias ElPaso.Context.Storage

  @check_interval :timer.hours(1)

  # client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Fuerza una ejecución immediate del auto-tune.
  """
  @spec run_now :: :ok
  def run_now do
    GenServer.cast(__MODULE__, :run_auto_tune)
  end

  @doc """
  Revierte el último auto-tune run.
  """
  @spec revert_last :: {:ok, String.t()} | {:error, String.t()}
  def revert_last do
    GenServer.call(__MODULE__, :revert_last)
  end

  # server callbacks

  @impl true
  def init(_opts) do
    state = %{
      last_run: nil,
      last_suggestions_applied: []
    }

    # Schedule next run
    schedule_next_run()

    {:ok, state}
  end

  @impl true
  def handle_info(:run_auto_tune, state) do
    do_auto_tune(state)
  end

  @impl true
  def handle_cast(:run_auto_tune, state) do
    {:noreply, state, {:continue, :run_now}}
  end

  @impl true
  def handle_continue(:run_now, state) do
    {:noreply, do_auto_tune(state)}
  end

  @impl true
  def handle_call(:revert_last, _from, state) do
    case Storage.get_last_auto_tune_run() do
      nil ->
        {:reply, {:error, "No hay auto-tune runs para revertir"}, state}

      last_run ->
        # Revertir cambios
        Enum.each(last_run.changes, fn change ->
          Config.Loader.update_affinity(change.model_id, change.task_type, change.previous_affinity)
          Logger.info("Revertido: #{change.model_id}.#{change.task_type}: #{change.new_affinity} → #{change.previous_affinity}")
        end)

        {:reply, {:ok, "Revertidos #{length(last_run.changes)} cambios"}, state}
    end
  end

  # private functions

  defp do_auto_tune(state) do
    if Config.auto_tune_enabled?() do
      Logger.info("Ejecutando auto-tune...")

      analyses = RouterAnalyzer.analyze_trends(:last_30d)
      min_confidence = Config.auto_tune_min_confidence()
      min_decisions = Config.auto_tune_min_decisions()

      # Filtrar sugerencias auto-aplicables
      appliable = Enum.filter(analyses, fn analysis ->
        analysis.n_decisions >= min_decisions and
          calculate_confidence(analysis) >= min_confidence and
          analysis.success_trend in [:improving, :degrading]
      end)

      # Aplicar cambios
      changes = Enum.map(appliable, fn analysis ->
        apply_suggestion(analysis)
      end)

      if length(changes) > 0 do
        # Guardar run para posible revert
        Storage.save_auto_tune_run(%{
          applied: length(changes),
          at: DateTime.utc_now(),
          changes: changes
        })

        # Emitir telemetry
        :telemetry.execute([:elpaso, :router, :auto_tuned], %{delta: length(changes)}, %{
          confidence: calculate_confidence(List.first(appliable)),
          task_type: List.first(appliable).task_type
        })

        Logger.info("Auto-tune aplicado: #{length(changes)} cambios")
      else
        Logger.info("Auto-tune: sin cambios aplicables")
      end

      new_state = %{
        last_run: DateTime.utc_now(),
        last_suggestions_applied: changes
      }

      schedule_next_run()
      {:noreply, new_state}
    else
      schedule_next_run()
      {:noreply, state}
    end
  end

  defp apply_suggestion(analysis) do
    suggested_affinity = calculate_best_affinity(analysis)
    current_affinity = Config.Loader.get_affinity(analysis.model_id, analysis.task_type)

    # Aplicar cambio
    Config.Loader.update_affinity(analysis.model_id, analysis.task_type, suggested_affinity)

    Logger.info("Auto-tune: #{analysis.model_id}.#{analysis.task_type}: #{current_affinity} → #{suggested_affinity}")

    %{
      model_id: analysis.model_id,
      task_type: analysis.task_type,
      previous_affinity: current_affinity,
      new_affinity: suggested_affinity
    }
  end

  defp calculate_confidence(analysis) do
    # Confianza basada en número de decisiones y varianza de la trend
    n_factor = min(analysis.n_decisions / 500.0, 1.0)

    trend_factor = case analysis.success_trend do
      :improving -> 0.9
      :degrading -> 1.0  # Alta confianza si está degradando
      :stable -> 0.5
    end

    n_factor * trend_factor
    |> Float.round(2)
  end

  defp calculate_best_affinity(analysis) do
    current = Config.Loader.get_affinity(analysis.model_id, analysis.task_type)
    
    # Aumentar affinity si está mejorando, reducir si está degradando
    case analysis.success_trend do
      :improving ->
        min(current + 0.1, 1.0)

      :degrading ->
        max(current - 0.15, 0.1)

      :stable ->
        current
    end
  end

  defp schedule_next_run do
    interval_ms = Config.auto_tune_check_interval_hours() * 3600 * 1000
    Process.send_after(self(), :run_auto_tune, interval_ms)
  end
end