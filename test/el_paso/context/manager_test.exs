defmodule ElPaso.Context.ManagerTest do
  @moduledoc """
  Tests para ElPaso.Context.Manager.
  """

  use ElPaso.DataCase, async: false

  alias ElPaso.Context.Manager
  alias ElPaso.Context.Storage

  setup do
    start_supervised!({Manager, []})
    :ok
  end

  describe "active_session_count/0" do
    test "devuelve 0 inicialmente" do
      assert Manager.active_session_count() == 0
    end
  end

  describe "get_or_create_session/2" do
    test "crea una nueva sesión si no existe" do
      assert {:ok, session_id, session_state} = Manager.get_or_create_session("sess-1", nil)
      assert is_binary(session_id)
      assert session_state.context_mode == "transparent"
      assert Manager.active_session_count() == 1
    end

    test "devuelve sesión existente" do
      {:ok, sid1, _} = Manager.get_or_create_session("sess-2", nil)
      {:ok, sid2, _} = Manager.get_or_create_session("sess-2", nil)
      assert sid1 == sid2
    end
  end

  describe "get_session_state/1" do
    test "devuelve estado de sesión existente" do
      {:ok, sid, state} = Manager.get_or_create_session("sess-3", nil)
      assert {:ok, ^state} = Manager.get_session_state(sid)
    end

    test "recarga desde PostgreSQL si no está en ETS" do
      {:ok, _} = Storage.create_session(%{session_id: "sess-4"})
      assert {:ok, state} = Manager.get_session_state("sess-4")
      assert state.session_id == "sess-4"
    end
  end

  describe "reload_session/1" do
    test "recarga una sesión desde PostgreSQL" do
      {:ok, _} = Storage.create_session(%{session_id: "sess-5"})
      assert {:ok, state} = Manager.reload_session("sess-5")
      assert state.session_id == "sess-5"
    end

    test "devuelve error si no existe" do
      assert {:error, :not_found} = Manager.reload_session("sess-none")
    end
  end

  describe "expire_session/1" do
    test "elimina sesión de ETS" do
      {:ok, sid, _} = Manager.get_or_create_session("sess-6", nil)
      assert :ok = Manager.expire_session(sid)
      assert Manager.active_session_count() == 0
    end
  end

  describe "update_session_state/2" do
    test "actualiza el estado de una sesión" do
      {:ok, sid, state} = Manager.get_or_create_session("sess-7", nil)
      new_state = %{state | context_mode: "sliding"}
      assert :ok = Manager.update_session_state(sid, new_state)
      assert {:ok, updated} = Manager.get_session_state(sid)
      assert updated.context_mode == "sliding"
    end
  end

  describe "list_sessions_by_user/1" do
    test "devuelve lista vacía sin sesiones" do
      assert Manager.list_sessions_by_user("user-none") == []
    end
  end
end
