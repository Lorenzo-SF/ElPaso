defmodule ElPaso.CLI.Commands.ContextTest do
  @moduledoc """
  Tests para ElPaso.CLI.Commands.Context.
  """

  use ElPaso.DataCase, async: true

  alias ElPaso.CLI.Commands.Context

  test "run muestra sesión no encontrada" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        Context.run(session: "nonexistent")
      end)

    assert output =~ "no encontrada"
  end

  test "run renderiza sesión existente en texto" do
    {:ok, _} = ElPaso.Context.Storage.create_session(%{session_id: "ctx-sess-1"})

    output =
      ExUnit.CaptureIO.capture_io(fn ->
        Context.run(session: "ctx-sess-1")
      end)

    assert output =~ "Sesión"
  end

  test "run renderiza sesión existente en JSON" do
    {:ok, _} = ElPaso.Context.Storage.create_session(%{session_id: "ctx-sess-2"})

    output =
      ExUnit.CaptureIO.capture_io(fn ->
        Context.run(session: "ctx-sess-2", format: :json)
      end)

    assert output =~ "session_id"
  end

  test "list_sessions muestra mensaje" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        Context.list_sessions()
      end)

    assert output =~ "sesiones"
  end
end
