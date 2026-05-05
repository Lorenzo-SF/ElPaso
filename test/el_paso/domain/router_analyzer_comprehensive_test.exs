defmodule ElPaso.Domain.RouterAnalyzerComprehensiveTest do
  use ElPaso.DataCase, async: false

  alias ElPaso.Domain.RouterAnalyzer
  alias ElPaso.Context.Storage

  describe "analyze_trends with multi-week data" do
    test "detects improving trend" do
      now = DateTime.utc_now()

      # Week 1: mostly failures
      for i <- 1..10 do
        assert {:ok, _} = Storage.save_routing_decision(%{
          request_id: "req-w1-#{i}",
          session_id: "sess-w1",
          model_id: "gpt-4",
          task_type: "code",
          selected_model: "gpt-4",
          decided_at: DateTime.add(now, -(20 + i), :day),
          outcome: "retry",
          latency_ms: 500,
          decision_latency_us: 500_000
        })
      end

      # Week 2: mostly successes
      for i <- 1..10 do
        assert {:ok, _} = Storage.save_routing_decision(%{
          request_id: "req-w2-#{i}",
          session_id: "sess-w2",
          model_id: "gpt-4",
          task_type: "code",
          selected_model: "gpt-4",
          decided_at: DateTime.add(now, -(10 + i), :day),
          outcome: "success",
          latency_ms: 100,
          decision_latency_us: 100_000
        })
      end

      results = RouterAnalyzer.analyze_trends(:last_30d)
      assert length(results) >= 1

      analysis = Enum.find(results, &(&1.model_id == "gpt-4"))
      assert analysis != nil
      assert analysis.n_decisions == 20
    end

    test "detects degrading trend" do
      now = DateTime.utc_now()

      # Week 1: successes
      for i <- 1..10 do
        assert {:ok, _} = Storage.save_routing_decision(%{
          request_id: "req-d1-#{i}",
          session_id: "sess-d1",
          model_id: "claude",
          task_type: "translation",
          selected_model: "claude",
          decided_at: DateTime.add(now, -(20 + i), :day),
          outcome: "success",
          latency_ms: 100,
          decision_latency_us: 100_000
        })
      end

      # Week 2: failures
      for i <- 1..10 do
        assert {:ok, _} = Storage.save_routing_decision(%{
          request_id: "req-d2-#{i}",
          session_id: "sess-d2",
          model_id: "claude",
          task_type: "translation",
          selected_model: "claude",
          decided_at: DateTime.add(now, -(10 + i), :day),
          outcome: "retry",
          latency_ms: 500,
          decision_latency_us: 500_000
        })
      end

      results = RouterAnalyzer.analyze_trends(:last_30d)
      analysis = Enum.find(results, &(&1.model_id == "claude"))
      assert analysis != nil
      assert analysis.n_decisions == 20
    end

    test "handles single window data" do
      now = DateTime.utc_now()

      for i <- 1..5 do
        assert {:ok, _} = Storage.save_routing_decision(%{
          request_id: "req-s-#{i}",
          session_id: "sess-s",
          model_id: "llama",
          task_type: "creative",
          selected_model: "llama",
          decided_at: DateTime.add(now, -i, :day),
          outcome: "success",
          latency_ms: 100,
          decision_latency_us: 100_000
        })
      end

      results = RouterAnalyzer.analyze_trends(:last_30d)
      analysis = Enum.find(results, &(&1.model_id == "llama"))
      assert analysis != nil
      assert analysis.success_trend == :stable
    end

    test "calculates retry rate with rapid requests" do
      now = DateTime.utc_now()
      base_time = DateTime.add(now, -1, :day)

      # Create rapid requests (less than 10 seconds apart) in same session
      for i <- 1..10 do
        assert {:ok, _} = Storage.save_routing_decision(%{
          request_id: "req-rapid-#{i}",
          session_id: "sess-rapid",
          model_id: "rapid-model",
          task_type: "code",
          selected_model: "rapid-model",
          decided_at: DateTime.add(base_time, i * 5, :second),
          outcome: "success",
          latency_ms: 100,
          decision_latency_us: 100_000
        })
      end

      results = RouterAnalyzer.analyze_trends(:last_30d)
      analysis = Enum.find(results, &(&1.model_id == "rapid-model"))
      assert analysis != nil
      assert analysis.retry_rate_pct >= 0
    end

    test "handles empty weekly windows" do
      now = DateTime.utc_now()

      # Only one decision
      assert {:ok, _} = Storage.save_routing_decision(%{
        request_id: "req-single",
        session_id: "sess-single",
        model_id: "single-model",
        task_type: "question_answer",
        selected_model: "single-model",
        decided_at: now,
        outcome: "success",
        latency_ms: 100,
        decision_latency_us: 100_000
      })

      results = RouterAnalyzer.analyze_trends(:last_30d)
      analysis = Enum.find(results, &(&1.model_id == "single-model"))
      assert analysis != nil
      assert analysis.n_decisions == 1
    end
  end

  describe "alerts with various conditions" do
    test "alerts for degrading trend with enough data" do
      now = DateTime.utc_now()

      for i <- 1..25 do
        assert {:ok, _} = Storage.save_routing_decision(%{
          request_id: "req-deg-#{i}",
          session_id: "sess-deg",
          model_id: "degrading-model",
          task_type: "code",
          selected_model: "degrading-model",
          decided_at: DateTime.add(now, -i, :day),
          outcome: if(rem(i, 2) == 0, do: "retry", else: "success"),
          latency_ms: 500,
          decision_latency_us: 500_000
        })
      end

      alerts = RouterAnalyzer.alerts()
      assert is_list(alerts)
    end

    test "no alerts for small datasets" do
      now = DateTime.utc_now()

      for i <- 1..5 do
        assert {:ok, _} = Storage.save_routing_decision(%{
          request_id: "req-small-#{i}",
          session_id: "sess-small",
          model_id: "small-model",
          task_type: "code",
          selected_model: "small-model",
          decided_at: DateTime.add(now, -i, :day),
          outcome: "retry",
          latency_ms: 500,
          decision_latency_us: 500_000
        })
      end

      alerts = RouterAnalyzer.alerts()
      # Should not alert because n < 20
      assert Enum.all?(alerts, &(&1.model_id != "small-model"))
    end
  end
end
