defmodule ElPaso.HTTP do
  @moduledoc """
  Módulo HTTP del sistema.
  
  Este módulo implementa el servidor HTTP para las APIs REST del proyecto.
  """

  use Plug.Router

  alias ElPaso.HTTP.RequestParser
  alias ElPaso.Context.Manager
  alias ElPaso.Domain.Router
  alias ElPaso.Engine.Dispatcher

  plug :match
  plug :dispatch

  # Endpoint para la inferencia
  get "/infer" do
    conn
    |> put_status(200)
    |> json(%{message: "Endpoint de inferencia"})
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

  # Endpoint principal de chat completions
  post "/v1/chat/completions" do
    with {:ok, body} <- read_body(conn),
         {:ok, params} <- RequestParser.parse_chat_request(body),
         session_id <- params[:session_id] || generate_session_id(),
         {:ok, _} <- Manager.get_or_create_session(session_id),
         {:ok, model_id, decision} <- Router.route(
           params[:request_id],
           session_id,
           params[:messages] |> last_user_message()
         ),
         {:ok, prompt} <- Context.Builder.build(session_id, last_user_message(params),
                                                   context_spec_for(model_id)),
         response <- Engine.infer(model_id, prompt, params) do
      Manager.append_turn(session_id, last_user_message(params), response, model_id)
      Router.record_outcome(params[:request_id], :success, response.latency_ms)
      send_response(conn, response, session_id, decision)
    else
      {:error, reason} -> send_error(conn, reason)
    end
  end

  # Funciones auxiliares
  defp json(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> resp(200, Jason.encode!(data))
  end

  defp read_body(conn) do
    case Plug.Conn.read_body(conn) do
      {:ok, body} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  defp last_user_message(messages) do
    messages |> Enum.filter(&(&1.role == "user")) |> List.last() |> Map.get("content", "")
  end

  defp generate_session_id() do
    # Generar un UUID v4 como ID de sesión
    :crypto.strong_rand_bytes(16) |> Base.encode16()
  end

  defp context_spec_for(model_id) do
    # Obtener el especificador de contexto para un modelo
    ElPaso.Config.context_spec_for(model_id)
  end

  defp send_response(conn, response, session_id, decision) do
    # Enviar respuesta al cliente
    
    conn
    |> put_status(200)
    |> put_resp_header("elpaso-session-id", session_id)
    |> json(response)
  end

  defp send_error(conn, reason) do
    # Enviar error al cliente
    
    error_response = %{
      error: %{
        message: "Error en la solicitud: #{inspect(reason)}",
        type: "bad_request",
        code: "elpaso_400"
      }
    }
    
    conn
    |> put_status(400)
    |> json(error_response)
  end
end