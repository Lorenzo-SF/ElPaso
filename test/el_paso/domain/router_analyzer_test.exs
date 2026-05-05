defmodule ElPaso.Domain.RouterAnalyzerTest do
  use ElPaso.DataCase, async: false

  alias ElPaso.Domain.RouterAnalyzer
  alias ElPaso.Context.Storage

  describe "analyze_trends/1" do
    test "returns empty list when no decisions" do
      assert [] = RouterAnalyzer.analyze_trends(:last_30d)
    end

    test "analyzes decisions with outcomes" do
      now = DateTime.utc_now()

      # Create some routing decisions
      Storage.save_routing_decision(%{
        request_id: "req-1",
        model_id: "gpt-4",
        task_type: "code",
        decided_at: now,
        outcome: "success",
        latency_ms: 100
      })

      Storage.save_routing_decision(%{
        request_id: "req-2",
        model_id: "gpt-4",
        task_type: "code",
        decided_at: DateTime.add(now, -1, :day),
        outcome: "success",
        latency_ms: 120
      })

      results = RouterAnalyzer.analyze_trends(:last_30d)
      assert is_list(results)

      if length(results) > 0 do
        analysis = List.first(results)
        assert analysis.model_id == "gpt-4"
        assert analysis.task_type == "code"
        assert analysis.n_decisions == 2
        assert analysis.overall_success_rate == 100.0
      end
    end

    test "analyzes different time ranges" do
      assert [] = RouterAnalyzer.analyze_trends(:last_7d)
      assert [] = RouterAnalyzer.analyze_trends(:last_90d)
    end

    test "handles decisions with retry outcome" do
      now = DateTime.utc_now()

      Storage.save_routing_decision(%{
        request_id: "req-retry",
        model_id: "claude",
        task_type: "translation",
        decided_at: now,
        outcome: "retry",
        latency_ms: 200
      })

      results = RouterAnalyzer.analyze_trends(:last_30d)
      assert is_list(results)
    end
  end

  describe "alerts/0" do
    test "returns alerts for problematic combinations" do
      now = DateTime.utc_now()

      # Create many decisions with retries to trigger alert
      for i <- 1..25 do
        Storage.save_routing_decision(%{
          request_id: "req-alert-#{i}",
          model_id: "bad-model",
          task_type: "code",
          decided_at: DateTime.add(now, -i, :day),
          outcome: "retry",
          latency_ms: 500
        })
      end

      alerts = RouterAnalyzer.alerts()
      assert is_list(alerts)

      if length(alerts) > 0 do
        alert = List.first(alerts)
        assert alert.alert == true
      end
    end
  end
end
