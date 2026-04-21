defmodule ElPaso.Domain.ModelManager do
  @moduledoc """
  Gestor de motores de inferencia con tolerancia a fallos.
  
  Este módulo coordina el arranque y gestión de los distintos motores 
  de inferencia, implementando políticas de reintentos y monitoreo.
  """

  use GenServer

  alias Zaguan.Engine
  alias Zaguan.Engine.Policies

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(_args) do
    # Política para motores locales: reintentar 3 veces con backoff exponencial
    policy = Policies.new(
      on_error: :retry,
      max_retries: 3,
      retry_delay: 2000,
      on_timeout: :stop,
      timeout: 60_000
    )

    {:ok, %{policy: policy}}
  end

  @doc """
  Arranca un proceso del motor de inferencia.
  """
  def start_engine_process(model_config, merged_args) do
    cmd = build_command(model_config.engine_binary, merged_args)

    # Zaguan.Engine.execute lanza el Worker bajo WorkerSupervisor
    # y aplica la política de reintentos automáticamente
    case Engine.execute(fn -> launch_and_monitor(cmd, model_config) end,
           policy: policy,
           timeout: 60_000) do
      {:ok, result} -> {:ok, result}
      {:error, err} -> {:error, err.message}
    end
  end

  @doc """
  Verifica la salud de todos los modelos.
  """
  def check_all_health(model_ids) do
    tasks = Enum.map(model_ids, fn id ->
      fn -> {id, do_health_check(id)} end
    end)

    case Engine.run(tasks, workers: length(model_ids), timeout: 5_000) do
      {:ok, result} ->
        # Suscribirse a eventos para recibir resultados individuales
        Engine.subscribe()
        {:ok, result.data.batch_id}
      {:error, err} ->
        {:error, err}
    end
  end

  defp build_command(engine_binary, args) do
    # Construye el comando para ejecutar el motor
    engine_binary <> " " <> Enum.join(args, " ")
  end

  defp launch_and_monitor(cmd, model_config) do
    # Lógica para lanzar y monitorear el proceso del motor
    :ok
  end

  defp do_health_check(_id) do
    # Lógica de verificación de salud del modelo
    :ok
  end
end