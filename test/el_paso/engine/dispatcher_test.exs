defmodule ElPaso.Engine.DispatcherTest do
  use ElPaso.DataCase, async: false
  alias ElPaso.Engine.Dispatcher

  setup do
    start_supervised!(ElPaso.Domain.ModelManager)
    :ok
  end

  describe "dispatch/1" do
    test "returns error when no model_hint and no models available" do
      result = Dispatcher.dispatch(%{messages: [%{role: "user", content: "test"}]})
      assert match?({:error, %{type: :no_model_available}}, result)
    end

    test "uses explicit model_hint when provided" do
      result = Dispatcher.dispatch(%{
        messages: [%{role: "user", content: "test"}],
        model_hint: "nonexistent-model"
      })

      assert match?({:error, _}, result)
    end

    test "handles string-keyed messages" do
      result = Dispatcher.dispatch(%{"messages" => [%{"role" => "user", "content" => "test"}]})
      assert match?({:error, _}, result)
    end

    test "handles empty messages" do
      result = Dispatcher.dispatch(%{messages: []})
      assert match?({:error, _}, result)
    end

    test "handles missing messages" do
      result = Dispatcher.dispatch(%{})
      assert match?({:error, _}, result)
    end
  end
end
