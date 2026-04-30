defmodule ElPaso.ModelDownloaderRegistryTest do
  @moduledoc """
  Tests para ModelDownloaderRegistry.
  """

  use ExUnit.Case, async: false

  setup do
    try do
      :ets.delete(:model_downloads)
    catch
      _, _ -> :ok
    end

    ModelDownloaderRegistry.init()
    :ok
  end

  describe "register/2" do
    test "registra un download" do
      assert true = ModelDownloaderRegistry.register("dl-1", %{status: :starting})
      assert ModelDownloaderRegistry.get("dl-1").status == :starting
    end
  end

  describe "update/2" do
    test "actualiza un download existente" do
      ModelDownloaderRegistry.register("dl-2", %{status: :starting})
      assert :skip != ModelDownloaderRegistry.update("dl-2", %{status: :downloading})
      assert ModelDownloaderRegistry.get("dl-2").status == :downloading
    end

    test "skip si no existe" do
      assert :skip = ModelDownloaderRegistry.update("dl-none", %{})
    end
  end

  describe "get/1" do
    test "devuelve nil si no existe" do
      assert ModelDownloaderRegistry.get("dl-none") == nil
    end
  end

  describe "list_all/0" do
    test "lista downloads registrados" do
      ModelDownloaderRegistry.register("dl-3", %{status: :complete})
      assert length(ModelDownloaderRegistry.list_all()) == 1
    end
  end
end
