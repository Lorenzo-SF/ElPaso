defmodule ElPaso.CLI.Commands.RouterStats do
  alias Zaguan.Drawer.Components.{Header, Separator, Table}
  alias ElPaso.Domain.RouterStats

  def run(opts) do
    since = opts[:since] || :last_24h
    report = RouterStats.aggregate(since)

    Header.print("Routing Stats", subtitle: "#{period_label(since)}")

    Separator.print("Resumen global")

    Table.print(
      headers: ["Métrica", "Valor"],
      rows: [
        ["Total decisiones", to_string(report.total_decisions)],
        ["Fallbacks", "#{report.fallback_count} (#{report.fallback_rate_pct}%)"],
        ["Cold starts", to_string(report.cold_starts)],
        ["Errores", to_string(report.error_count)]
      ],
      headers_color: :cyan,
      table_border: :rounded
    )

    Separator.print("Por modelo")

    model_rows =
      report.by_model
      |> Enum.map(fn {model, s} ->
        [
          model,
          to_string(s.total_calls),
          "#{s.avg_latency_ms}ms",
          "#{s.p95_latency_ms}ms",
          to_string(s.error_count)
        ]
      end)

    Table.print(
      headers: ["Modelo", "Calls", "Avg", "p95", "Errores"],
      rows: model_rows,
      headers_color: :yellow,
      table_border: :rounded
    )

    if opts[:format] == "json" do
      Zaguan.Drawer.Components.Json.print(report)
    end
  end

  defp period_label(since) do
    case since do
      :last_hour -> "Última hora"
      :last_24h -> "Últimas 24 horas"
      :last_7d -> "Últimos 7 días"
      {:since, dt} -> DateTime.to_iso8601(dt)
    end
  end
end
