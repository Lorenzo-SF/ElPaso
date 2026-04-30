defmodule ElPaso.Storage.S3AdapterTest do
  @moduledoc """
  Tests para ElPaso.Storage.S3Adapter.
  """

  use ExUnit.Case, async: true

  alias ElPaso.Storage.S3Adapter

  describe "parse_s3_uri/1 (vía funciones públicas)" do
    test "download_if_missing devuelve skipped si el archivo existe" do
      tmp = Path.join(System.tmp_dir!(), "s3_test_#{System.unique_integer()}")
      File.write!(tmp, "content")
      assert {:error, :skipped} = S3Adapter.download_if_missing("s3://bucket/key", tmp)
      File.rm!(tmp)
    end

    test "download_if_missing devuelve error para URI inválido" do
      assert_raise RuntimeError, ~r/Invalid S3 URI/, fn ->
        S3Adapter.download_model("invalid", "/tmp/x")
      end
    end

    test "upload devuelve error si el archivo no existe" do
      assert {:error, :file_not_found} = S3Adapter.upload("/nonexistent/file", "s3://bucket/key")
    end

    test "exists? devuelve false sin credenciales válidas" do
      refute S3Adapter.exists?("s3://bucket/key")
    end
  end
end
