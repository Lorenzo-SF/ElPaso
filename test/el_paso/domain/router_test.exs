defmodule ElPaso.Domain.RouterTest do
  @moduledoc """
  Tests para ElPaso.Domain.Router.
  """

  use ElPaso.DataCase, async: true

  alias ElPaso.Domain.Router
  alias ElPaso.Context.Storage
  alias ElPaso.Models.User

  describe "update_routing_outcome/2" do
    test "actualiza el resultado de un enrutamiento existente" do
      {:ok, user} = ElPaso.Repo.insert(%User{username: "router-test", role: "user"})
      {:ok, session} = Storage.create_session(%{session_id: "sess-123", user_id: user.id})

      {:ok, _} =
        Storage.save_routing_decision(%{
          session_id: "sess-123",
          request_id: "req-123",
          selected_model: "gpt-4",
          model_id: "gpt-4",
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
