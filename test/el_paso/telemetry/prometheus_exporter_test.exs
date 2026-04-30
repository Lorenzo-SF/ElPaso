defmodule ElPaso.Telemetry.PrometheusExporterTest do
  @moduledoc """
  Tests para ElPaso.Telemetry.PrometheusExporter.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Telemetry.PrometheusExporter

  test "metrics devuelve lista" do
    metrics = PrometheusExporter.metrics()
    assert is_list(metrics)
    assert length(metrics) > 0
    assert hd(metrics).type in [:counter, :distribution, :last_value]
  end
end
