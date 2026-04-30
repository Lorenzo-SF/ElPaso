defmodule ElPaso.Domain.RouterAnalyzerTest do
  @moduledoc """
  Tests para ElPaso.Domain.RouterAnalyzer.
  """

  use ElPaso.DataCase, async: true

  alias ElPaso.Domain.RouterAnalyzer
  alias ElPaso.Context.Storage

  describe "analyze_trends/1" do
    test "devuelve lista vacía sin decisiones" do
      assert RouterAnalyzer.analyze_trends(:last_7d) == []
    end

    test "analiza combinaciones con decisiones existentes" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      for i <- 1..5 do
        Storage.save_routing_decision(%{
          request_id: "r#{i}",
          session_id: "s1",
          model_id: "gpt-4",
          task_type: "code",
          selected_model: "gpt-4",
          decided_at: DateTime.add(now, -i * 3600),
          outcome: "success",
          latency_ms: 100
        })
      end

      results = RouterAnalyzer.analyze_trends(:last_7d)
      assert length(results) >= 1
      analysis = hd(results)
      assert analysis.model_id == "gpt-4"
      assert analysis.task_type == "code"
      assert analysis.n_decisions == 5
      assert analysis.overall_success_rate == 100.0
    end
  end

  describe "alerts/0" do
    test "devuelve lista vacía sin alertas" do
      assert RouterAnalyzer.alerts() == []
    end
  end
end
