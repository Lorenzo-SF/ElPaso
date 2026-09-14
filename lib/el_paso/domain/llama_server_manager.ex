defmodule ElPaso.Domain.LlamaServerManager do
  @moduledoc """
  Gestiona el ciclo de vida de llama-server.

  ElPaso arranca/apaga llama-server según la personalidad activa.
  Solo puede haber UN modelo cargado a la vez (limitación de GPU).
  Cuando el router selecciona una personalidad con un modelo distinto,
  este manager mata el proceso actual y arranca el nuevo.

  Usa el wrapper ~/bin/localllama para arrancar con los flags óptimos.
  """

  use GenServer
  require Logger


  @wrapper "localllama"
  @port 8081
  @health_check_timeout 30_000
  @health_check_interval 500

  # ─── Client API ──────────────────────────────────────────────────────────

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5_000
    }
  end

  @doc """
  Asegura que el modelo `model_name` esté cargado en llama-server.
  Si ya está cargado, no hace nada. Si hay otro modelo, lo mata y arranca el nuevo.
  Bloquea hasta que el servidor responde a health check.
  """
  @spec ensure_model(String.t()) :: :ok | {:error, term()}
  def ensure_model(model_name) do
    GenServer.call(__MODULE__, {:ensure_model, model_name}, 60_000)
  end

  @doc "Devuelve el modelo actualmente cargado, o nil."
  @spec current_model() :: String.t() | nil
  def current_model do
    GenServer.call(__MODULE__, :current_model)
  end

  # ─── GenServer Callbacks ─────────────────────────────────────────────────

  @impl GenServer
  def init(_opts) do
    Logger.info("[LlamaServerManager] Inicializado. Sin modelo cargado.")
    {:ok, %{current_model: nil, port: @port}}
  end

  @impl GenServer
  def handle_call(:current_model, _from, state) do
    {:reply, state.current_model, state}
  end

  @impl GenServer
  def handle_call({:ensure_model, model_name}, _from, state) do
    if state.current_model == model_name do
      Logger.debug("[LlamaServerManager] Modelo '#{model_name}' ya cargado.")
      {:reply, :ok, state}
    else
      Logger.info("[LlamaServerManager] Cambiando modelo: #{state.current_model || "ninguno"} → #{model_name}")

      # 1. Parar el servidor actual
      kill_current()

      # 2. Arrancar el nuevo
      case start_llama(model_name) do
        :ok ->
          # 3. Esperar health check
          if wait_until_ready() do
            Logger.info("[LlamaServerManager] Modelo '#{model_name}' listo en puerto #{state.port}")
            {:reply, :ok, %{state | current_model: model_name}}
          else
            Logger.error("[LlamaServerManager] Timeout esperando health check de '#{model_name}'")
            {:reply, {:error, :health_check_timeout}, %{state | current_model: nil}}
          end

        {:error, reason} ->
          Logger.error("[LlamaServerManager] Error arrancando '#{model_name}': #{inspect(reason)}")
          {:reply, {:error, reason}, %{state | current_model: nil}}
      end
    end
  end

  # ─── Private ─────────────────────────────────────────────────────────────

  defp kill_current do
    Logger.info("[LlamaServerManager] Parando llama-server actual...")

    case ElPaso.Ecosystem.run_with_runner(@wrapper, ["stop"], timeout: 15_000) do
      {:ok, output} ->
        Logger.debug("[LlamaServerManager] Stop OK: #{String.trim(output)}")

      {:error, output} ->
        Logger.warning("[LlamaServerManager] Stop warning: #{String.trim(output)}")
    end

    # Pequeña pausa para liberar el puerto
    Process.sleep(1_000)
  end

  defp start_llama(model_name) do
    Logger.info("[LlamaServerManager] Arrancando llama-server con modelo '#{model_name}'...")

    case ElPaso.Ecosystem.run_with_runner(@wrapper, [model_name, "quiet"], timeout: 120_000) do
      {:ok, output} ->
        Logger.debug("[LlamaServerManager] Start OK: #{String.trim(output)}")
        :ok

      {:error, output} ->
        Logger.error("[LlamaServerManager] Start failed: #{String.trim(output)}")
        {:error, output}
    end
  end

  defp wait_until_ready do
    deadline = System.monotonic_time(:millisecond) + @health_check_timeout

    Stream.iterate(0, &(&1 + 1))
    |> Enum.reduce_while(false, fn _, _ ->
      if System.monotonic_time(:millisecond) > deadline do
        {:halt, false}
      else
        case health_check() do
          :ok -> {:halt, true}
          _ ->
            Process.sleep(@health_check_interval)
            {:cont, false}
        end
      end
    end)
  end

  defp health_check do
    url = "http://localhost:#{@port}/v1/models"

    case Finch.build(:get, url)
         |> Finch.request(ElPaso.Finch, receive_timeout: 2_000) do
      {:ok, %{status: 200}} -> :ok
      _ -> :not_ready
    end
  rescue
    _ -> :not_ready
  end
end
