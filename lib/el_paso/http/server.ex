defmodule ElPaso.HTTP.Server do
  @moduledoc """
  Router HTTP principal de ElPaso.

  Expone endpoints compatibles con OpenAI y Anthropic, además de
  métricas Prometheus, dashboard web, health checks y administración.

  Incluye headers de seguridad (CSP, HSTS, X-Frame-Options) y
  parsers JSON con límite de 10MB.
  """

  use Plug.Router
  require Logger

  import Plug.Conn

  # ── Security Plugs ─────────────────────────────────────────
  plug(:add_security_headers)

  plug(Plug.Parsers,
    parsers: [:json],
    json_decoder: Jason,
    # 10MB max body size
    length: 10_000_000
  )

  plug(:match)
  plug(:dispatch)

  # V1.3: Add dashboard route
  forward "/dashboard", to: ElPaso.HTTP.Dashboard

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
    params = conn.body_params

    # Validar tamaño de mensajes
    messages = Map.get(params, "messages", [])

    total_chars =
      messages |> Enum.map(&Map.get(&1, "content", "")) |> Enum.join() |> String.length()

    if total_chars > 100_000 do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(413, Jason.encode!(%{error: "Request too large", max_chars: 100_000}))
    else
      with internal_req <- ElPaso.HTTP.AnthropicProxy.from_anthropic(params),
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
  end

  # V2.0: Anthropic streaming endpoint
  post "/v1/messages_stream" do
    params = conn.body_params
    internal_req = ElPaso.HTTP.AnthropicProxy.from_anthropic(params)

    # Configurar streaming response
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    # Iniciar streaming
    run_anthropic_stream(internal_req, conn)
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
    alerts =
      if ElPaso.Config.auto_tune_enabled?() do
        ElPaso.Domain.RouterAnalyzer.alerts()
        |> Enum.map(fn a ->
          %{
            type: "quality_degradation",
            model_id: a.model_id,
            task_type: Atom.to_string(a.task_type),
            retry_rate_pct: a.retry_rate_pct,
            trend: Atom.to_string(a.success_trend),
            n_decisions: a.n_decisions
          }
        end)
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

  # V3.0: Endpoint de autenticación JWT con rate limiting
  post "/auth/token" do
    client_ip = get_client_ip(conn)

    case ElPaso.Security.RateLimiter.check_rate("auth:#{client_ip}", 5) do
      :ok ->
        params = conn.body_params
        user_id = Map.get(params, "user_id")
        api_key = Map.get(params, "api_key")

        if ElPaso.Security.Auth.valid_api_key?(api_key) do
          token = ElPaso.Security.JWT.generate_token(user_id, :user)

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(
            200,
            Jason.encode!(%{
              token: token,
              expires_in: 86400
            })
          )
        else
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(
            401,
            Jason.encode!(%{
              error: "unauthorized",
              message: "Invalid credentials"
            })
          )
        end

      {:error, :rate_limited} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, Jason.encode!(%{error: "rate_limited", retry_after: 60}))
    end
  end

  # V3.0: Admin endpoints requieren autenticación y rate limiting
  get "/admin/sessions" do
    with :ok <- check_admin_rate(conn),
         {:ok, _user} <- verify_admin_auth(conn) do
      sessions = ElPaso.Context.Storage.list_sessions()

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{sessions: sessions}))
    else
      {:error, :rate_limited} ->
        send_rate_limited(conn)

      _ ->
        conn
        |> put_status(403)
        |> send_resp(403, Jason.encode!(%{error: "admin access required"}))
    end
  end

  get "/admin/users" do
    with :ok <- check_admin_rate(conn),
         {:ok, _user} <- verify_admin_auth(conn) do
      users = ElPaso.Context.Storage.list_users()

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{users: users}))
    else
      {:error, :rate_limited} ->
        send_rate_limited(conn)

      _ ->
        conn
        |> put_status(403)
        |> send_resp(403, Jason.encode!(%{error: "admin access required"}))
    end
  end

  get "/admin/usage/report" do
    with :ok <- check_admin_rate(conn),
         {:ok, _user} <- verify_admin_auth(conn) do
      report =
        ElPaso.Context.Storage.usage_report(
          user_id: Map.get(conn.params, "user_id"),
          model_id: Map.get(conn.params, "model_id"),
          period: Map.get(conn.params, "period", "30d")
        )

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(report))
    else
      {:error, :rate_limited} ->
        send_rate_limited(conn)

      _ ->
        conn
        |> put_status(403)
        |> send_resp(403, Jason.encode!(%{error: "admin access required"}))
    end
  end

  get "/admin/usage/report.csv" do
    with :ok <- check_admin_rate(conn),
         {:ok, _user} <- verify_admin_auth(conn) do
      report = ElPaso.Context.Storage.usage_report_csv(conn.params)

      conn
      |> put_resp_content_type("text/csv")
      |> send_resp(200, report)
    else
      {:error, :rate_limited} ->
        send_rate_limited(conn)

      _ ->
        conn
        |> put_status(403)
        |> send_resp(403, Jason.encode!(%{error: "admin access required"}))
    end
  end

  # ── Security Helpers ────────────────────────────────────────

  defp add_security_headers(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    # Obsoleto pero por compatibilidad
    |> put_resp_header("x-xss-protection", "0")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=()")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
    )
    |> maybe_add_hsts()
  end

  defp maybe_add_hsts(conn) do
    if Application.get_env(:elpaso, :env) == :prod do
      put_resp_header(conn, "strict-transport-security", "max-age=31536000; includeSubDomains")
    else
      conn
    end
  end

  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ips | _] -> ips |> String.split(",") |> List.first() |> String.trim()
      _ -> to_string(:inet.ntoa(conn.remote_ip))
    end
  end

  defp check_admin_rate(conn) do
    client_ip = get_client_ip(conn)
    ElPaso.Security.RateLimiter.check_rate("admin:#{client_ip}", 10)
  end

  defp send_rate_limited(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(429, Jason.encode!(%{error: "rate_limited", retry_after: 60}))
  end

  # Helper para verificar admin auth
  defp verify_admin_auth(conn) do
    case get_req_header(conn, "authorization") do
      [auth_header] ->
        token = String.replace(auth_header, ~r/^Bearer\s+/i, "")

        case ElPaso.Security.JWT.verify_token(token) do
          {:ok, %{role: :admin}} -> {:ok, %{role: :admin}}
          _ -> {:error, :not_admin}
        end

      _ ->
        {:error, :no_token}
    end
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
    events = ElPaso.Telemetry.Store.recent_events(100)

    # Contar eventos por tipo
    inference_complete = Enum.count(events, fn e -> e.name == "elpaso.inference.complete" end)
    inference_error = Enum.count(events, fn e -> e.name == "elpaso.inference.error" end)
    router_fallback = Enum.count(events, fn e -> e.name == "elpaso.router.fallback" end)
    cold_starts = Enum.count(events, fn e -> e.name == "elpaso.model.cold_start" end)

    # Calcular latencias
    latencies =
      events
      |> Enum.filter(fn e -> e.name == "elpaso.inference.complete" end)
      |> Enum.map(fn e -> Map.get(e.measurements || %{}, :latency_ms, 0) end)

    avg_latency = if latencies == [], do: 0.0, else: Enum.sum(latencies) / length(latencies)

    [
      "# HELP elpaso_prefix_cache_hit_ratio Ratio de cache hit del prefijo",
      "# TYPE elpaso_prefix_cache_hit_ratio gauge",
      "elpaso_prefix_cache_hit_ratio #{:erlang.float_to_binary(hit_ratio * 1.0, [{:decimals, 4}])}",
      "",
      "# HELP elpaso_inference_complete_total Total de inferencias completadas",
      "# TYPE elpaso_inference_complete_total counter",
      "elpaso_inference_complete_total #{inference_complete}",
      "",
      "# HELP elpaso_inference_error_total Total de errores de inferencia",
      "# TYPE elpaso_inference_error_total counter",
      "elpaso_inference_error_total #{inference_error}",
      "",
      "# HELP elpaso_inference_avg_latency_ms Latencia media de inferencia",
      "# TYPE elpaso_inference_avg_latency_ms gauge",
      "elpaso_inference_avg_latency_ms #{:erlang.float_to_binary(avg_latency * 1.0, [{:decimals, 2}])}",
      "",
      "# HELP elpaso_router_fallback_total Fallbacks del router",
      "# TYPE elpaso_router_fallback_total counter",
      "elpaso_router_fallback_total #{router_fallback}",
      "",
      "# HELP elpaso_model_cold_start_total Arranques desde frío",
      "# TYPE elpaso_model_cold_start_total counter",
      "elpaso_model_cold_start_total #{cold_starts}",
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
    # Seleccionar modelo via router o usar model_hint
    {model_name, system_prompt, config_overrides} =
      case internal_req.model_hint do
        hint when hint in [nil, "", "auto"] ->
          case ElPaso.Domain.Router.select_personality(internal_req.messages) do
            {:ok, result} ->
              {result.model_name, result.system_prompt, result.config}

            {:error, _} ->
              {nil, nil, %{}}
          end

        name ->
          {name, nil, %{}}
      end

    if is_nil(model_name) do
      {:error, %{type: :no_model, message: "No model available for inference"}}
    else
      # Inyectar system_prompt de la personalidad como primer mensaje
      messages =
        if system_prompt do
          [%{role: "system", content: system_prompt} | internal_req.messages]
        else
          internal_req.messages
        end

      request = %{
        messages: messages,
        model_hint: model_name,
        temperature: Map.get(config_overrides, "temperature", internal_req.temperature),
        max_tokens: Map.get(config_overrides, "max_tokens", internal_req.max_tokens)
      }

      case ElPaso.Domain.ModelManager.infer(model_name, request) do
        {:ok, response} ->
          {:ok, response}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # V2.0: Ejecuta streaming para requests Anthropic
  defp run_anthropic_stream(internal_req, conn) do
    {model_name, system_prompt, _config_overrides} =
      case internal_req.model_hint do
        hint when hint in [nil, "", "auto"] ->
          case ElPaso.Domain.Router.select_personality(internal_req.messages) do
            {:ok, result} -> {result.model_name, result.system_prompt, result.config}
            {:error, _} -> {nil, nil, %{}}
          end

        name ->
          {name, nil, %{}}
      end

    if is_nil(model_name) do
      error_event =
        ElPaso.HTTP.AnthropicProxy.to_anthropic_stream_chunk(
          %{content: "Error: No model available"},
          :delta
        )

      send_chunk_data(conn, error_event)
      conn
    else
      start_event = ElPaso.HTTP.AnthropicProxy.stream_start_event(0)
      send_chunk_data(conn, start_event)

      messages =
        if system_prompt do
          [%{role: "system", content: system_prompt} | internal_req.messages]
        else
          internal_req.messages
        end

      model = ElPaso.Domain.ModelManager.get_model(model_name)

      if is_nil(model) do
        send_chunk_data(
          conn,
          ElPaso.HTTP.AnthropicProxy.to_anthropic_stream_chunk(
            %{content: "Model not found: #{model_name}"},
            :delta
          )
        )
      else
        engine = ElPaso.Repo.get(ElPaso.Models.Engine, model.engine_id)

        if is_nil(engine) do
          send_chunk_data(
            conn,
            ElPaso.HTTP.AnthropicProxy.to_anthropic_stream_chunk(
              %{content: "Engine not configured"},
              :delta
            )
          )
        else
          # Usar streaming del adapter
          callback = fn chunk ->
            delta_event = ElPaso.HTTP.AnthropicProxy.to_anthropic_stream_chunk(chunk, :delta)
            send_chunk_data(conn, delta_event)
          end

          case ElPaso.Engine.Adapter.stream_infer(messages, model, engine, %{}, callback) do
            :ok ->
              :ok

            {:error, reason} ->
              Logger.error("[Server] Stream error: #{inspect(reason)}")

              send_chunk_data(
                conn,
                ElPaso.HTTP.AnthropicProxy.to_anthropic_stream_chunk(
                  %{content: "Error: #{inspect(reason)}"},
                  :delta
                )
              )
          end
        end
      end

      # Enviar evento de fin
      stop_event = ElPaso.HTTP.AnthropicProxy.stream_stop_event(0)
      send_chunk_data(conn, stop_event)

      conn
    end
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
