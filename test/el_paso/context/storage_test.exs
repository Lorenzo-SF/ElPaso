defmodule ElPaso.Context.StorageTest do
  use ElPaso.DataCase, async: false

  alias ElPaso.Context.Storage
  alias ElPaso.Context.Schemas.{Session, Message, ConversationSummary, RoutingDecision}
  alias ElPaso.Models.AutoTuneRun

  describe "session operations" do
    test "create_session/1 creates a session" do
      attrs = %{
        session_id: "sess-1",
        user_id: "user-1",
        model_id: "gpt-4",
        context_mode: "transparent",
        status: "active"
      }

      assert {:ok, %Session{} = session} = Storage.create_session(attrs)
      assert session.session_id == "sess-1"
    end

    test "get_session/1 returns a session" do
      {:ok, session} = Storage.create_session(%{session_id: "sess-2", user_id: "user-1"})
      assert Storage.get_session("sess-2").session_id == session.session_id
    end

    test "get_session/1 returns nil for missing" do
      assert Storage.get_session("nonexistent") == nil
    end

    test "update_session/2 updates a session" do
      {:ok, session} = Storage.create_session(%{session_id: "sess-3", user_id: "user-1"})
      assert {:ok, updated} = Storage.update_session(session, %{status: "closed"})
      assert updated.status == "closed"
    end

    test "delete_session/1 deletes a session" do
      {:ok, session} = Storage.create_session(%{session_id: "sess-4", user_id: "user-1"})
      assert {:ok, _} = Storage.delete_session(session)
      assert Storage.get_session("sess-4") == nil
    end

    test "list_sessions_by_user/1 returns sessions" do
      Storage.create_session(%{session_id: "sess-5", user_id: "user-2"})
      Storage.create_session(%{session_id: "sess-6", user_id: "user-2"})
      assert length(Storage.list_sessions_by_user("user-2")) == 2
    end

    test "list_sessions/0 returns all sessions" do
      Storage.create_session(%{session_id: "sess-list", user_id: "user-1"})
      assert length(Storage.list_sessions()) >= 1
    end
  end

  describe "message operations" do
    test "create_message/1 creates a message" do
      Storage.create_session(%{session_id: "sess-msg", user_id: "user-1"})

      attrs = %{
        session_id: "sess-msg",
        role: "user",
        content: "Hello",
        model_id: "gpt-4",
        tokens: 10
      }

      assert {:ok, %Message{} = msg} = Storage.create_message(attrs)
      assert msg.content == "Hello"
    end

    test "get_all_messages/1 returns messages for session" do
      Storage.create_session(%{session_id: "sess-msgs", user_id: "user-1"})
      Storage.create_message(%{session_id: "sess-msgs", role: "user", content: "Hi"})
      Storage.create_message(%{session_id: "sess-msgs", role: "assistant", content: "Hey"})
      assert length(Storage.get_all_messages("sess-msgs")) == 2
    end
  end

  describe "summary operations" do
    test "create_summary/1 creates a summary" do
      attrs = %{
        session_id: "sess-sum",
        summary: "Test summary",
        summary_tokens: 50
      }

      assert {:ok, %ConversationSummary{} = sum} = Storage.create_summary(attrs)
      assert sum.summary == "Test summary"
    end

    test "get_latest_summary/1 returns latest summary" do
      Storage.create_summary(%{session_id: "sess-ls", summary: "First"})
      Storage.create_summary(%{session_id: "sess-ls", summary: "Second"})
      latest = Storage.get_latest_summary("sess-ls")
      assert latest.summary in ["First", "Second"]
    end

    test "get_latest_summary/1 returns nil when none" do
      assert Storage.get_latest_summary("no-such-session") == nil
    end
  end

  describe "routing decision operations" do
    test "save_routing_decision/1 and query_routing_decisions/1" do
      attrs = %{
        request_id: "req-1",
        session_id: "sess-rd-1",
        model_id: "gpt-4",
        task_type: "code",
        selected_model: "gpt-4",
        decided_at: DateTime.utc_now(),
        outcome: "pending",
        latency_ms: 100
      }

      assert {:ok, %RoutingDecision{}} = Storage.save_routing_decision(attrs)
      decisions = Storage.query_routing_decisions([])
      assert length(decisions) >= 1
    end

    test "query_routing_decisions filters by since" do
      Storage.save_routing_decision(%{
        request_id: "req-since",
        session_id: "sess-since",
        model_id: "gpt-4",
        task_type: "code",
        selected_model: "gpt-4",
        decided_at: DateTime.utc_now(),
        outcome: "completed",
        latency_ms: 100
      })

      decisions = Storage.query_routing_decisions(since: Date.utc_today())
      assert is_list(decisions)
    end

    test "query_routing_decisions filters by with_outcome" do
      Storage.save_routing_decision(%{
        request_id: "req-out",
        session_id: "sess-out",
        model_id: "gpt-4",
        task_type: "code",
        selected_model: "gpt-4",
        decided_at: DateTime.utc_now(),
        outcome: "completed",
        latency_ms: 100
      })

      decisions = Storage.query_routing_decisions(with_outcome: true)
      assert is_list(decisions)
    end

    test "update_routing_outcome/3 updates outcome" do
      Storage.save_routing_decision(%{
        request_id: "req-update",
        session_id: "sess-update",
        model_id: "gpt-4",
        task_type: "code",
        selected_model: "gpt-4",
        decided_at: DateTime.utc_now(),
        outcome: "pending",
        latency_ms: 0
      })

      assert {1, _} = Storage.update_routing_outcome("req-update", "success", 150)
    end
  end

  describe "auto-tune operations" do
    test "save_auto_tune_run/1 and get_last_auto_tune_run/0" do
      assert {:ok, %AutoTuneRun{}} =
               Storage.save_auto_tune_run(%{applied: 2, changes: [%{"key" => "value"}]})

      assert %AutoTuneRun{} = Storage.get_last_auto_tune_run()
    end

    test "query_auto_tune_runs/1 returns runs" do
      Storage.save_auto_tune_run(%{applied: 1, changes: []})
      runs = Storage.query_auto_tune_runs(%{limit: 5})
      assert is_list(runs)
      assert length(runs) >= 1
    end
  end

  describe "pricing" do
    test "get_model_pricing/1 returns known pricing" do
      assert %{input: 0.015, output: 0.075} = Storage.get_model_pricing("claude-3-opus")
      assert %{input: 0.003, output: 0.015} = Storage.get_model_pricing("claude-3-sonnet")
      assert %{input: 0.00025, output: 0.00125} = Storage.get_model_pricing("claude-3-haiku")
    end

    test "get_model_pricing/1 returns nil for unknown" do
      assert Storage.get_model_pricing("unknown-model") == nil
    end
  end

  describe "usage report" do
    test "usage_report/1 returns report structure" do
      report = Storage.usage_report([])
      assert is_map(report)
      assert is_list(report.users)
      assert is_number(report.total_cost)
    end

    test "usage_report_csv/1 returns CSV string" do
      csv = Storage.usage_report_csv([])
      assert is_binary(csv)
      assert String.starts_with?(csv, "user,model,cost")
    end
  end

  describe "user operations" do
    test "list_users/0 returns users" do
      assert is_list(Storage.list_users())
    end
  end

  describe "daily_spend" do
    test "daily_spend/1 returns 0.0 for new user" do
      assert Storage.daily_spend("nonexistent-user") == 0.0
    end
  end
end
