defmodule ElPaso.HTTP.Server do
  use Plug.Router

  import Plug.Conn

  plug(:match)
  plug(:dispatch)

  # V1.3: Add dashboard route
  get "/dashboard" do
    ElPaso.HTTP.Dashboard.call(conn, [])
  end

  # V1.3: Metrics endpoint using TelemetryMetricsPrometheus
  get "/metrics" do
    # Generate Prometheus metrics from Telemetry.Store
    metrics = generate_prometheus_metrics()

    conn
    |> put_resp_content_type("text/plain; charset=utf-8")
    |> send_resp(200, metrics)
  end

  # V1.3: WebSocket handler
  get "/v1/chat/ws" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, ~s({"status":"websocket_endpoint_ready","path":"/v1/chat/ws"}))
  end

  # V2.0: Anthropic API compatible endpoint
  post "/v1/messages" do
    with {:ok, body, _conn} <- read_body(conn),
         {:ok, params} <- Jason.decode(body),
         internal_req <- ElPaso.HTTP.AnthropicProxy.from_anthropic(params),
         {:ok, response} <- run_anthropic_pipeline(internal_req, conn) do
      anthropic_resp = ElPaso.HTTP.AnthropicProxy.to_anthropic(response, params["model"])

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(anthropic_resp))
    else
      {:error, reason} ->
        error_resp = %{
          "error" => %{
            "type" => "invalid_request_error",
            "message" => "Error processing request: #{inspect(reason)}"
          }
        }

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(error_resp))
    end
  end

  # V2.0: Anthropic streaming endpoint
  post "/v1/messages_stream" do
    with {:ok, body, _conn} <- read_body(conn),
         {:ok, params} <- Jason.decode(body),
         internal_req <- ElPaso.HTTP.AnthropicProxy.from_anthropic(params) do
      # Configurar streaming response
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

      # Iniciar streaming
      run_anthropic_stream(internal_req, conn)
    else
      {:error, reason} ->
        error_resp = %{
          "error" => %{
            "type" => "invalid_request_error",
            "message" => "Error processing request: #{inspect(reason)}"
          }
        }

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(error_resp))
    end
  end

  # Endpoint para la inferencia
  get "/infer" do
    conn
    |> put_status(200)
    |> json(%{message: "Endpoint de inferencia"})
  end

  # V2.2: Endpoint para estado del sistema con alertas de degradación
  get "/status" do
    # Obtener alertas del router si auto_tune está habilitado
    alerts = if ElPaso.Config.auto_tune_enabled?() do
      ElPaso.Domain.RouterAnalyzer.alerts()
      |> Enum.map(fn a -> %{
        type: "quality_degradation",
        model_id: a.model_id,
        task_type: Atom.to_string(a.task_type),
        retry_rate_pct: a.retry_rate_pct,
        trend: Atom.to_string(a.success_trend),
        n_decisions: a.n_decisions
      } end)
    else
      []
    end

    conn
    |> put_status(200)
    |> json(%{
      status: "ok",
      alerts: alerts
    })
  end

  # Endpoint para el estado del modelo
  get "/models/status" do
    conn
    |> put_status(200)
    |> json(%{message: "Estado de los modelos"})
  end

  # Endpoint para el enrutamiento
  post "/route" do
    conn
    |> put_status(200)
    |> json(%{message: "Enrutamiento de solicitudes"})
  end

  defp json(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> resp(200, Jason.encode!(data))
  end

  # Genera métricas Prometheus en formato texto
  defp generate_prometheus_metrics do
    hit_ratio = ElPaso.Telemetry.Store.prefix_cache_hit_ratio()
    # events = ElPaso.Telemetry.Store.recent_events(100) # Para métricas dinámicas futuras

    [
      "# HELP elpaso_prefix_cache_hit_ratio Ratio de cache hit del prefijo",
      "# TYPE elpaso_prefix_cache_hit_ratio gauge",
      "elpaso_prefix_cache_hit_ratio #{:erlang.float_to_binary(hit_ratio, [{:decimals, 4}])}",
      "",
      "# HELP elpaso_inference_complete_total Total de inferencias completadas",
      "# TYPE elpaso_inference_complete_total counter",
      "elpaso_inference_complete_total 0",
      "",
      "# HELP elpaso_inference_complete_latency_ms Latencia de inferencia en ms",
      "# TYPE elpaso_inference_complete_latency_ms histogram",
      "elpaso_inference_complete_latency_ms_bucket{le=\"100\"} 0",
      "elpaso_inference_complete_latency_ms_bucket{le=\"500\"} 0",
      "elpaso_inference_complete_latency_ms_bucket{le=\"1000\"} 0",
      "elpaso_inference_complete_latency_ms_bucket{le=\"+Inf\"} 0",
      "elpaso_inference_complete_latency_ms_sum 0",
      "elpaso_inference_complete_latency_ms_count 0",
      "",
      "# HELP elpaso_router_fallback_total Total de fallbacks del router",
      "# TYPE elpaso_router_fallback_total counter",
      "elpaso_router_fallback_total{reason=\"timeout\"} 0",
      "elpaso_router_fallback_total{reason=\"error\"} 0",
      "",
      "# HELP elpaso_model_cold_start_startup_duration_ms Duración de arranque desde frío",
      "# TYPE elpaso_model_cold_start_startup_duration_ms histogram",
      "elpaso_model_cold_start_startup_duration_ms_bucket{le=\"1000\"} 0",
      "elpaso_model_cold_start_startup_duration_ms_bucket{le=\"5000\"} 0",
      "elpaso_model_cold_start_startup_duration_ms_bucket{le=\"+Inf\"} 0",
      "elpaso_model_cold_start_startup_duration_ms_sum 0",
      "elpaso_model_cold_start_startup_duration_ms_count 0",
      ""
    ]
    |> Enum.join("\n")
  end

  def start_link(_args) do
    {:ok, _} = Plug.Cowboy.http(__MODULE__, [])
    {:ok, self()}
  end

  # V2.0: Ejecuta el pipeline para requests Anthropic
  defp run_anthropic_pipeline(internal_req, _conn) do
    # Por ahora, devuelve una respuesta de ejemplo
    # En producción, esto invocaría el pipeline completo
    prompt = internal_req.messages |> List.first() |> Map.get("content", "")
    estimated_tokens = div(String.length(prompt), 4)

    {:ok,
     %{
       content: "Response to: #{prompt}",
       finish_reason: :stop,
       prompt_tokens: estimated_tokens,
       completion_tokens: div(String.length(prompt), 4)
     }}
  end

  # V2.0: Ejecuta streaming para requests Anthropic
  defp run_anthropic_stream(internal_req, conn) do
    # Enviar evento de inicio
    start_event = ElPaso.HTTP.AnthropicProxy.stream_start_event(0)
    chunk(conn, start_event)

    # Obtener prompt
    prompt = internal_req.messages |> List.first() |> Map.get("content", "")

    # Simular streaming
    words = String.split(prompt, " ")
    total_words = length(words)

    Enum.each(words, fn word ->
      delta_event =
        ElPaso.HTTP.AnthropicProxy.to_anthropic_stream_chunk(
          %{content: word <> " ", tokens: nil},
          :delta
        )

      send_chunk_data(conn, delta_event)
      Process.sleep(50)
    end)

    # Enviar evento de fin
    stop_event = ElPaso.HTTP.AnthropicProxy.stream_stop_event(total_words)
    send_chunk_data(conn, stop_event)

    conn
  end

  # Helper para enviar chunks en streaming
  defp send_chunk_data(conn, data) do
    case conn do
      %{adapter: {adapter, adapter_state}} ->
        adapter.send_chunk(adapter_state, data)
        conn

      _ ->
        conn
    end
  end
end
