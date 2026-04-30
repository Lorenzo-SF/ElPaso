defmodule ElPaso.ModelDownloaderTest do
  @moduledoc """
  Tests para ElPaso.ModelDownloader.
  """

  use ExUnit.Case, async: false

  alias ElPaso.ModelDownloader

  setup do
    try do
      ModelDownloaderRegistry.init()
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  describe "download/2" do
    test "devuelve error con config inválida" do
      assert {:error, :invalid_source_config} = ModelDownloader.download(%{})
    end
  end

  describe "verify_checksum/2" do
    test "verifica checksum correcto" do
      tmp = Path.join(System.tmp_dir!(), "mdl_test_#{System.unique_integer()}")
      File.write!(tmp, "content")
      expected = :crypto.hash(:sha256, "content") |> Base.encode16(case: :lower)
      assert :ok = ModelDownloader.verify_checksum(tmp, expected)
      File.rm!(tmp)
    end

    test "falla si el checksum no coincide" do
      tmp = Path.join(System.tmp_dir!(), "mdl_test_#{System.unique_integer()}")
      File.write!(tmp, "content")
      assert {:error, :checksum_mismatch} = ModelDownloader.verify_checksum(tmp, "badhash")
      refute File.exists?(tmp)
    end
  end
end
