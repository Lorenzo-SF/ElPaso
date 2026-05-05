defmodule ElPaso.ModelDownloaderTest do
  use ExUnit.Case, async: false

  alias ElPaso.ModelDownloader
  alias ModelDownloaderRegistry

  setup do
    # Ensure ETS table exists
    if :ets.whereis(:model_downloads) == :undefined do
      ModelDownloaderRegistry.init()
    end

    :ok
  end

  describe "download/2" do
    test "returns error for invalid config" do
      assert {:error, :invalid_source_config} = ModelDownloader.download(%{})
    end

    test "returns error when missing repo_id" do
      assert {:error, :invalid_source_config} = ModelDownloader.download(%{"filename" => "model.bin"})
    end

    test "returns error when missing filename" do
      assert {:error, :invalid_source_config} = ModelDownloader.download(%{"repo_id" => "user/model"})
    end

    test "starts download with valid config" do
      config = %{
        "repo_id" => "test/repo",
        "filename" => "model.bin",
        "revision" => "main"
      }

      assert {:ok, download_id} = ModelDownloader.download(config)
      assert is_binary(download_id)
    end
  end

  describe "progress/1" do
    test "returns error for unknown download" do
      assert {:error, :not_found} = ModelDownloader.progress("nonexistent-id")
    end

    test "returns progress for registered download" do
      ModelDownloaderRegistry.register("test-dl", %{
        url: "http://test",
        dest: "/tmp/test",
        status: :downloading,
        repo_id: "test/repo",
        filename: "model.bin",
        downloaded_bytes: 50,
        total_bytes: 100
      })

      assert {:ok, info} = ModelDownloader.progress("test-dl")
      assert info.status == :downloading
      assert info.percent == 50
    end
  end

  describe "list_downloads/0" do
    test "returns list of downloads" do
      assert is_list(ModelDownloader.list_downloads())
    end
  end

  describe "cancel/1" do
    test "cancels a download" do
      ModelDownloaderRegistry.register("cancel-dl", %{
        url: "http://test",
        dest: "/tmp/test",
        status: :downloading,
        repo_id: "test/repo",
        filename: "model.bin",
        downloaded_bytes: 0,
        total_bytes: 0
      })

      assert :ok = ModelDownloader.cancel("cancel-dl")
      assert ModelDownloaderRegistry.get("cancel-dl").status == :cancelled
    end
  end

  describe "verify_checksum/2" do
    test "returns ok for matching checksum" do
      content = "test content"
      path = "/tmp/test_checksum"
      File.write!(path, content)

      expected = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
      assert :ok = ModelDownloader.verify_checksum(path, expected)

      File.rm(path)
    end

    test "returns error and deletes file for mismatch" do
      content = "test content"
      path = "/tmp/test_checksum_bad"
      File.write!(path, content)

      assert {:error, :checksum_mismatch} = ModelDownloader.verify_checksum(path, "badhash")
      refute File.exists?(path)
    end
  end
end
