defmodule ElPaso.ModelDownloader do
  @moduledoc """
  Downloads models from HuggingFace Hub with streaming, progress tracking, and checksum verification.
  """

  @hf_base_url "https://huggingface.co"
  @download_dir Application.compile_env(:elpaso, :default_models_dir, "~/modelos")

  @doc """
  Starts a model download from HuggingFace Hub.
  """
  def download(source_config, opts \\ []) do
    repo_id = Map.get(source_config, "repo_id")
    filename = Map.get(source_config, "filename")

    unless repo_id && filename do
      {:error, :invalid_source_config}
    else
      revision = Map.get(source_config, "revision", "main")
      dest_path = opts[:dest] || default_dest_path(repo_id, filename)

      download_id = generate_download_id()
      url = build_hf_url(repo_id, filename, revision)

      # Register download in ETS for progress tracking
      ModelDownloaderRegistry.register(download_id, %{
        url: url,
        dest: dest_path,
        status: :starting,
        repo_id: repo_id,
        filename: filename,
        downloaded_bytes: 0,
        total_bytes: 0
      })

      # Start download task
      Task.start(fn ->
        do_download(download_id, url, dest_path, Map.get(source_config, "sha256"))
      end)

      {:ok, download_id}
    end
  end

  @doc """
  Returns the progress of an active download.
  """
  def progress(download_id) do
    case ModelDownloaderRegistry.get(download_id) do
      nil ->
        {:error, :not_found}

      info ->
        pct = calculate_percentage(info.downloaded_bytes, info.total_bytes)

        {:ok,
         %{
           id: download_id,
           status: info.status,
           repo_id: info.repo_id,
           filename: info.filename,
           downloaded_bytes: info.downloaded_bytes,
           total_bytes: info.total_bytes,
           percent: pct
         }}
    end
  end

  @doc """
  Lists all active downloads.
  """
  def list_downloads do
    ModelDownloaderRegistry.list_all()
  end

  @doc """
  Cancels an active download.
  """
  def cancel(download_id) do
    ModelDownloaderRegistry.update(download_id, %{status: :cancelled})
    :ok
  end

  @doc """
  Verifies the SHA256 checksum of a downloaded file.
  """
  def verify_checksum(path, expected_sha256) do
    actual =
      :crypto.hash(:sha256, File.read!(path))
      |> Base.encode16(case: :lower)

    if actual == expected_sha256 do
      :ok
    else
      File.rm!(path)
      {:error, :checksum_mismatch}
    end
  end

  # Private functions

  defp do_download(download_id, url, dest_path, expected_sha256) do
    File.mkdir_p!(Path.dirname(dest_path))
    temp_path = dest_path <> ".tmp"

    ModelDownloaderRegistry.update(download_id, %{status: :downloading})

    try do
      result =
        Finch.build(:get, url)
        |> Finch.stream(
          ElPasoFinch,
          {File.open!(temp_path, [:write, :binary]), 0},
          fn
            {:status, status}, acc when status == 200 ->
              {:cont, acc}

            {:status, status}, _acc ->
              {:halt, {:error, "HTTP #{status}"}}

            {:headers, headers}, acc ->
              total = get_content_length(headers)
              ModelDownloaderRegistry.update(download_id, %{total_bytes: total})
              {:cont, acc}

            {:data, chunk}, {file, downloaded} ->
              IO.binwrite(file, chunk)
              new_downloaded = downloaded + byte_size(chunk)

              if rem(new_downloaded, 1_048_576) < byte_size(chunk) do
                ModelDownloaderRegistry.update(download_id, %{downloaded_bytes: new_downloaded})
              end

              {:cont, {file, new_downloaded}}
          end
        )

      case result do
        {:ok, _} ->
          if expected_sha256 do
            case verify_checksum(temp_path, expected_sha256) do
              :ok ->
                :ok

              {:error, reason} ->
                ModelDownloaderRegistry.update(download_id, %{status: {:error, reason}})
                File.rm(temp_path)
            end
          end

          File.rename!(temp_path, dest_path)

          ModelDownloaderRegistry.update(download_id, %{
            status: :complete,
            dest_path: dest_path,
            downloaded_bytes: get_file_size(dest_path)
          })

          :telemetry.execute([:elpaso, :model, :downloaded], %{}, %{dest: dest_path})

        {:error, reason} ->
          File.rm(temp_path)
          ModelDownloaderRegistry.update(download_id, %{status: {:error, reason}})
      end
    rescue
      e ->
        ModelDownloaderRegistry.update(download_id, %{status: {:error, Exception.message(e)}})
    end
  end

  defp build_hf_url(repo_id, filename, revision) do
    "#{@hf_base_url}/#{repo_id}/resolve/#{revision}/#{filename}"
  end

  defp default_dest_path(repo_id, filename) do
    basename = Path.basename(repo_id)
    Path.join([@download_dir, basename, filename])
  end

  defp get_content_length(headers) do
    case List.keyfind(headers, "content-length", 0) do
      {"content-length", length} -> String.to_integer(length)
      nil -> 0
    end
  end

  defp calculate_percentage(_, 0), do: 0

  defp calculate_percentage(downloaded, total) do
    round(downloaded / total * 100)
  end

  defp get_file_size(path) do
    case File.stat(path) do
      {:ok, stat} -> stat.size
      _ -> 0
    end
  end

  defp generate_download_id do
    "dl_#{:crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)}"
  end
end

# Registry for tracking downloads
defmodule ModelDownloaderRegistry do
  @table :model_downloads

  def register(id, info) do
    :ets.insert(@table, {id, Map.put(info, :registered_at, System.system_time(:second))})
  end

  def update(id, updates) do
    case :ets.lookup(@table, id) do
      [{id, existing}] ->
        :ets.insert(@table, {id, Map.merge(existing, updates)})

      [] ->
        :skip
    end
  end

  def get(id) do
    case :ets.lookup(@table, id) do
      [{_, info}] -> info
      [] -> nil
    end
  end

  def list_all do
    :ets.tab2list(@table)
    |> Enum.map(fn {id, info} -> Map.put(info, :id, id) end)
  end

  def init do
    :ets.new(@table, [:named_table, :public, :set])
  end
end
