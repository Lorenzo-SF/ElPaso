defmodule ElPaso.Context.StorageTest do
  @moduledoc """
  Tests exhaustivos para ElPaso.Context.Storage.
  """

  use ElPaso.DataCase, async: true

  alias ElPaso.Context.Storage
  alias ElPaso.Context.Schemas.{Session, Message, RoutingDecision, ConversationSummary}
  alias ElPaso.Models.{ApiUsage, AutoTuneRun, User}

  setup do
    {:ok, user} = ElPaso.Repo.insert(%User{username: "storage-test", role: "user"})
    %{user: user}
  end

  describe "create_session/1" do
    test "crea una sesión", %{user: user} do
      assert {:ok, %Session{} = s} = Storage.create_session(%{session_id: "s1", user_id: user.id})
      assert s.session_id == "s1"
    end
  end

  describe "get_session/1" do
    test "obtiene sesión por id", %{user: user} do
      {:ok, s} = Storage.create_session(%{session_id: "s2", user_id: user.id})
      assert Storage.get_session(s.session_id).session_id == "s2"
    end

    test "devuelve nil si no existe" do
      assert Storage.get_session("none") == nil
    end
  end

  describe "update_session/2" do
    test "actualiza una sesión", %{user: user} do
      {:ok, s} = Storage.create_session(%{session_id: "s3", user_id: user.id})
      assert {:ok, %Session{} = updated} = Storage.update_session(s, %{context_mode: "sliding"})
      assert updated.context_mode == "sliding"
    end
  end

  describe "delete_session/1" do
    test "elimina una sesión", %{user: user} do
      {:ok, s} = Storage.create_session(%{session_id: "s4", user_id: user.id})
      assert {:ok, %Session{}} = Storage.delete_session(s)
      assert Storage.get_session("s4") == nil
    end
  end

  describe "list_sessions_by_user/1" do
    test "lista sesiones de un usuario", %{user: user} do
      {:ok, _} = Storage.create_session(%{session_id: "s5", user_id: user.id})
      assert length(Storage.list_sessions_by_user(user.id)) == 1
    end
  end

  describe "create_message/1 and get_all_messages/1" do
    test "crea y lista mensajes" do
      {:ok, m} = Storage.create_message(%{session_id: "s1", role: "user", content: "hola"})
      assert m.role == "user"
      assert length(Storage.get_all_messages("s1")) == 1
    end
  end

  describe "create_summary/1 and get_latest_summary/1" do
    test "crea y obtiene resumen" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        Storage.create_summary(%{
          session_id: "s1",
          summary: "resumen",
          window_start: now,
          window_end: now
        })

      assert Storage.get_latest_summary("s1").summary == "resumen"
    end
  end

  describe "save_routing_decision/1 and update_routing_outcome/3" do
    test "guarda y actualiza decisión" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, d} =
        Storage.save_routing_decision(%{
          request_id: "r1",
          session_id: "s1",
          model_id: "gpt-4",
          task_type: "code",
          selected_model: "gpt-4",
          decided_at: now
        })

      assert d.request_id == "r1"
      assert {1, _} = Storage.update_routing_outcome("r1", "success", 150)
    end
  end

  describe "query_routing_decisions/1" do
    test "filtra decisiones", %{user: user} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        Storage.save_routing_decision(%{
          request_id: "r2",
          session_id: "s1",
          model_id: "gpt-4",
          task_type: "code",
          selected_model: "gpt-4",
          decided_at: now,
          outcome: "success"
        })

      assert length(
               Storage.query_routing_decisions(
                 since: Date.add(Date.utc_today(), -1),
                 with_outcome: true
               )
             ) >= 1

      assert length(Storage.query_routing_decisions([])) >= 1
    end
  end

  describe "save_auto_tune_run/1 and query_auto_tune_runs/1" do
    test "guarda y consulta auto-tune runs" do
      {:ok, _} = Storage.save_auto_tune_run(%{applied: 2, changes: %{}})
      assert length(Storage.query_auto_tune_runs(%{limit: 5})) >= 1
    end
  end

  describe "get_last_auto_tune_run/0" do
    test "obtiene el último auto-tune run" do
      assert Storage.get_last_auto_tune_run() == nil
      {:ok, _} = Storage.save_auto_tune_run(%{applied: 1, changes: %{}})
      assert Storage.get_last_auto_tune_run() != nil
    end
  end

  describe "upsert_api_usage/1 and daily_spend/1" do
    test "registra uso y calcula gasto diario" do
      today = Date.utc_today()

      assert :ok =
               Storage.upsert_api_usage(%{
                 user_id: "u1",
                 model_id: "gpt-4",
                 date: today,
                 input_tokens: 100,
                 output_tokens: 50,
                 cost_usd: Decimal.from_float(0.5)
               })

      assert Storage.daily_spend("u1") == 0.5
    end
  end

  describe "list_sessions/0" do
    test "lista todas las sesiones", %{user: user} do
      {:ok, _} = Storage.create_session(%{session_id: "s6", user_id: user.id})
      assert length(Storage.list_sessions()) >= 1
    end
  end

  describe "list_users/0" do
    test "lista todos los usuarios" do
      assert length(Storage.list_users()) >= 1
    end
  end

  describe "usage_report/1" do
    test "genera reporte de uso" do
      today = Date.utc_today()

      Storage.upsert_api_usage(%{
        user_id: "u1",
        model_id: "gpt-4",
        date: today,
        input_tokens: 10,
        output_tokens: 5,
        cost_usd: Decimal.from_float(1.0)
      })

      report = Storage.usage_report([])
      assert is_map(report)
      assert is_list(report.users)
      assert is_number(report.total_cost)
    end
  end

  describe "usage_report_csv/1" do
    test "genera CSV" do
      today = Date.utc_today()

      Storage.upsert_api_usage(%{
        user_id: "u1",
        model_id: "gpt-4",
        date: today,
        input_tokens: 10,
        output_tokens: 5,
        cost_usd: Decimal.from_float(1.0)
      })

      csv = Storage.usage_report_csv([])
      assert is_binary(csv)
      assert csv =~ "user,model,cost"
    end
  end

  describe "get_model_pricing/1" do
    test "devuelve pricing para modelos conocidos" do
      assert Storage.get_model_pricing("claude-3-opus") == %{input: 0.015, output: 0.075}
      assert Storage.get_model_pricing("claude-3-sonnet") == %{input: 0.003, output: 0.015}
      assert Storage.get_model_pricing("claude-3-haiku") == %{input: 0.00025, output: 0.00125}
    end

    test "devuelve nil para modelos desconocidos" do
      assert Storage.get_model_pricing("unknown") == nil
    end
  end
end
