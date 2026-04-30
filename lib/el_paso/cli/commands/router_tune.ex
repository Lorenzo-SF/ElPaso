defmodule ElPaso.CLI.Commands.RouterTune do
  @moduledoc """
  Comando para ajustar el enrutamiento de modelos.
  """

  alias ElPaso.CLI.Output

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
        Output.success(message)

      {:error, message} ->
        Output.error(message)
    end
  end

  defp run_tuner(_opts) do
    Output.info("Ejecutando análisis de tendencias...")

    analyses = ElPaso.Domain.RouterAnalyzer.analyze_trends(:last_30d)

    if Enum.empty?(analyses) do
      Output.warning(
        "No hay datos suficientes para análisis. Se necesitan al menos 500 routing_decisions."
      )
    else
      print_analyses(analyses)
    end
  end

  defp print_analyses(analyses) do
    Output.section("Análisis de tendencias")

    rows =
      Enum.map(analyses, fn a ->
        trend =
          case a.success_trend do
            :improving -> "↑ Mejorando"
            :degrading -> "↓ Degradando"
            :stable -> "→ Estable"
          end

        alert = if a.alert, do: "⚠️", else: ""

        [
          "#{a.model_id}@#{a.task_type}",
          "#{a.overall_success_rate}%",
          trend,
          to_string(a.n_decisions),
          alert
        ]
      end)

    Output.data_table(
      ["Modelo@Tarea", "Success Rate", "Trend", "N", "Alerta"],
      rows,
      headers_color: :yellow
    )

    Output.divider("Detalle por métrica")

    detail_rows =
      Enum.map(analyses, fn a ->
        [
          "#{a.model_id}@#{a.task_type}",
          "#{a.retry_rate_pct}%",
          "#{a.median_latency_ms}ms"
        ]
      end)

    Output.data_table(
      ["Modelo@Tarea", "Retry Rate", "Latencia mediana"],
      detail_rows
    )
  end
end
