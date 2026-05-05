defmodule ElPaso.HTTP.Dashboard do
  @moduledoc """
  Dashboard web para monitoreo de ElPaso.

  Sirve una página HTML con métricas en tiempo real (sesiones activas,
  tokens, decisiones de routing, cache hit ratio) y un endpoint JSON
  `/api/state` consumido por el frontend.
  """

  use Plug.Router

  import Plug.Conn

  # Aliases for referenced modules
  alias ElPaso.Telemetry.Store

  plug(:match)
  plug(:dispatch)

  get "/" do
    html = dashboard_html()

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  get "/api/state" do
    state = %{
      models: [],
      sessions: %{
        active: 0,
        tokens_24h: 0
      },
      router: %{
        decisions_1h: 0,
        fallback_rate: 0.0
      },
      prefix_cache: %{
        hit_ratio: Store.prefix_cache_hit_ratio()
      },
      recent_events: Store.recent_events(10)
    }

    json_response(conn, state)
  end

  defp json_response(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(data))
  end

  defp dashboard_html do
    """
    <!DOCTYPE html>
    <html>
      <head>
        <title>ElPaso Dashboard</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
          .card { background: white; border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
          .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; }
          h1 { color: #333; }
          h2 { color: #555; font-size: 1.2em; margin-top: 0; }
          p { font-size: 2em; margin: 10px 0; color: #007bff; }
          .model-card { background: #e9ecef; padding: 10px; border-radius: 3px; margin: 5px 0; }
          .model-status-hot { color: #28a745; }
          .model-status-warming { color: #ffc107; }
          .model-status-cold { color: #dc3545; }
        </style>
      </head>
      <body>
        <h1>ElPaso Dashboard</h1>
        <div id="dashboard-content">
          <div class="metrics-grid">
            <div class="card">
              <h2>Active Sessions</h2>
              <p id="active-sessions">Loading...</p>
            </div>
            <div class="card">
              <h2>Tokens 24h</h2>
              <p id="tokens-24h">Loading...</p>
            </div>
            <div class="card">
              <h2>Decisions 1h</h2>
              <p id="decisions-1h">Loading...</p>
            </div>
            <div class="card">
              <h2>Fallback Rate</h2>
              <p id="fallback-rate">Loading...</p>
            </div>
            <div class="card">
              <h2>Prefix Cache Hit Ratio</h2>
              <p id="cache-hit-ratio">Loading...</p>
            </div>
          </div>
          <div class="card" style="margin-top: 20px;">
            <h2>Recent Events</h2>
            <ul id="recent-events"></ul>
          </div>
        </div>
        <script>
          function formatTimestamp(ts) {
            return new Date(ts * 1000).toLocaleTimeString();
          }

          function updateDashboard() {
            fetch('/dashboard/api/state')
              .then(response => response.json())
              .then(data => {
                document.getElementById('active-sessions').textContent = data.sessions.active;
                document.getElementById('tokens-24h').textContent = data.sessions.tokens_24h.toLocaleString();
                document.getElementById('decisions-1h').textContent = data.router.decisions_1h;
                document.getElementById('fallback-rate').textContent = data.router.fallback_rate + '%';
                document.getElementById('cache-hit-ratio').textContent = Math.round(data.prefix_cache.hit_ratio * 100) + '%';

                const eventsList = document.getElementById('recent-events');
                eventsList.innerHTML = data.recent_events.map(e =>
                  '<li>' + formatTimestamp(e.timestamp) + ': ' + e.name + '</li>'
                ).join('');
              })
              .catch(err => console.error('Failed to fetch dashboard state:', err));
          }
          setInterval(updateDashboard, 5000);
          updateDashboard();
        </script>
      </body>
    </html>
    """
  end
end
