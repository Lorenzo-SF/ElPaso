defmodule ElPaso.Domain.RouterTest do
  @moduledoc """
  Tests para ElPaso.Domain.Router.
  """

  use ElPaso.DataCase, async: true

  alias ElPaso.Domain.Router
  alias ElPaso.Domain.ModelManager
  alias ElPaso.Context.Storage
  alias ElPaso.Models.{User, Engine}

  setup do
    {:ok, engine} =
      ElPaso.Repo.insert(%Engine{
        name: "router-engine",
        adapter: "ollama",
        base_url: "http://localhost:11434"
      })

    {:ok, _} =
      ModelManager.create_model(%{name: "gpt-4-test", engine_id: engine.id, active: true})

    %{engine: engine}
  end

  describe "select_model/2" do
    test "selecciona el primer modelo activo" do
      assert {:ok, decision} = Router.select_model([], %{})
      assert decision.model_name == "gpt-4-test"
      assert is_binary(decision.decision_reason)
    end

    test "devuelve error si no hay modelos activos", %{engine: engine} do
      ModelManager.stop_model("gpt-4-test")
      assert {:error, :no_active_model} = Router.select_model([], %{})
    end
  end

  describe "get_model_state/1" do
    test "devuelve estado de modelo existente" do
      assert {:ok, state} = Router.get_model_state("gpt-4-test")
      assert state.name == "gpt-4-test"
      assert state.status == "active"
    end

    test "devuelve error si no existe" do
      assert {:error, :model_not_found} = Router.get_model_state("nonexistent")
    end
  end

  describe "get_routing_config/1" do
    test "devuelve config de modelo existente" do
      assert {:ok, config} = Router.get_routing_config("gpt-4-test")
      assert is_map(config.task_affinity)
    end

    test "devuelve error si no existe" do
      assert {:error, :model_not_found} = Router.get_routing_config("nonexistent")
    end
  end

  describe "update_routing_outcome/2" do
    test "actualiza el resultado de un enrutamiento existente", %{engine: _engine} do
      {:ok, user} = ElPaso.Repo.insert(%User{username: "router-test", role: "user"})
      {:ok, _session} = Storage.create_session(%{session_id: "sess-123", user_id: user.id})

      {:ok, _} =
        Storage.save_routing_decision(%{
          session_id: "sess-123",
          request_id: "req-123",
          selected_model: "gpt-4-test",
          model_id: "gpt-4-test",
          task_type: "code",
          decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      assert :ok =
               Router.update_routing_outcome("req-123", %{outcome: "success", response_time: 150})
    end

    test "devuelve error si el enrutamiento no existe" do
      assert {:error, :not_found} =
               Router.update_routing_outcome("nonexistent", %{
                 outcome: "success",
                 response_time: 150
               })
    end
  end
end
