defmodule ElPaso.CLI.Commands.RouterTune do
  @moduledoc """
  Comando para ajustar el enrutamiento de modelos.
  """

  @doc """
  Ejecuta el comando de ajuste del enrutamiento.
  """
  def run(opts) do
    if opts[:revert_auto] do
      revert_auto_tune()
    else
      run_tuner(opts)
    end
  end

  defp revert_auto_tune do
    case ElPaso.Domain.AutoTuner.revert_last() do
      {:ok, message} ->
        IO.puts("✓ #{message}")

      {:error, message} ->
        IO.puts("✗ #{message}")
    end
  end

  defp run_tuner(_opts) do
    IO.puts("Ejecutando análisis de tendencias...")

    analyses = ElPaso.Domain.RouterAnalyzer.analyze_trends(:last_30d)

    if Enum.empty?(analyses) do
      IO.puts(
        "No hay datos suficientes para análisis. Se necesitan al menos 500 routing_decisions."
      )
    else
      print_analyses(analyses)
    end
  end

  defp print_analyses(analyses) do
    IO.puts("Análisis de tendencias:\n")

    analyses
    |> Enum.each(fn a ->
      trend_icon =
        case a.success_trend do
          :improving -> "↑"
          :degrading -> "↓"
          :stable -> "→"
        end

      status = if a.alert, do: "⚠️", else: ""

      IO.puts(
        "#{a.model_id}@#{a.task_type}: #{a.overall_success_rate}% #{trend_icon} (n=#{a.n_decisions}) #{status}"
      )

      IO.puts("  retry_rate: #{a.retry_rate_pct}%, latencia: #{a.median_latency_ms}ms")
    end)
  end
end
