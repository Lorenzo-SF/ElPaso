defmodule ElPaso.Storage.S3Adapter do
  @moduledoc """
  Adaptador para almacenamiento en S3.

  Permite descargar modelos y hacer backup de configuración desde/hacia S3.
  """

  require Logger

  @doc """
  Descarga un archivo desde S3 al path local.

  ## Parámetros
    - `s3_uri`: URI en formato "s3://bucket/path/to/file"
    - `local_path`: path donde guardar el archivo

  ## Ejemplo
      ElPaso.Storage.S3Adapter.download_model(
        "s3://my-bucket/models/llama-7b.gguf",
        "./models/llama-7b.gguf"
      )
  """
  @spec download_model(String.t(), String.t()) :: :ok | {:error, term()}
  def download_model(s3_uri, local_path) do
    %{bucket: bucket, key: key} = parse_s3_uri(s3_uri)

    # Asegurar que el directorio existe
    Path.dirname(local_path) |> File.mkdir_p()

    # Descargar usando ExAws con streaming
    try do
      ExAws.S3.download_file(bucket, key, local_path)
      |> ExAws.stream!()
      |> Stream.run()

      Logger.info("Descargado #{s3_uri} -> #{local_path}")
      :ok
    rescue
      error ->
        Logger.error("Error descargando desde S3: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Sube un archivo local a S3.

  ## Parámetros
    - `local_path`: path del archivo local
    - `s3_uri`: destino en formato "s3://bucket/path/to/file"
  """
  @spec upload(String.t(), String.t()) :: :ok | {:error, term()}
  def upload(local_path, s3_uri) do
    %{bucket: bucket, key: key} = parse_s3_uri(s3_uri)

    if File.exists?(local_path) do
      try do
        # Upload with streaming
        result =
          local_path
          |> File.stream!([], 65_536)
          |> ExAws.S3.upload(bucket, key)
          |> ExAws.request()

        case result do
          {:ok, _} ->
            Logger.info("Subido #{local_path} -> #{s3_uri}")
            :ok

          {:error, reason} ->
            Logger.error("Error subiendo a S3: #{inspect(reason)}")
            {:error, reason}
        end
      rescue
        error ->
          Logger.error("Error subiendo a S3: #{inspect(error)}")
          {:error, error}
      end
    else
      {:error, :file_not_found}
    end
  end

  @doc """
  Verifica si un archivo existe en S3.
  """
  @spec exists?(String.t()) :: boolean()
  def exists?(s3_uri) do
    %{bucket: bucket, key: key} = parse_s3_uri(s3_uri)

    case ExAws.S3.head_object(bucket, key) do
      {:ok, _} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  @doc """
  Descarga un modelo solo si no existe localmente.
  Se usa al iniciar ModelManager.
  """
  @spec download_if_missing(String.t(), String.t()) :: :ok | {:error, :skipped}
  def download_if_missing(s3_uri, local_path) do
    if File.exists?(local_path) do
      Logger.info("Modelo ya existe localmente: #{local_path}")
      {:error, :skipped}
    else
      download_model(s3_uri, local_path)
    end
  end

  # Parsea URI s3://bucket/key
  defp parse_s3_uri("s3://" <> rest) do
    [bucket | key_parts] = String.split(rest, "/", parts: 2)
    key = Enum.join(key_parts, "/")

    %{bucket: bucket, key: key}
  end

  defp parse_s3_uri(uri) do
    raise "Invalid S3 URI: #{uri}. Formato esperado: s3://bucket/path/to/file"
  end
end
