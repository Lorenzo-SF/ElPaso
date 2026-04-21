defmodule ElPaso.HTTP.WebSocketHandler do
  @moduledoc """
  Handler de WebSocket para chat en tiempo real.
  Implementa el protocolo WebSocket de Cowboy para conexiones persistentes.
  """
  @behaviour :cowboy_websocket

  @doc """
  Inicializa el handler de WebSocket.
  Extrae session_id y user_id de la query string.
  """
  def init(req, _opts) do
    session_id = :cowboy_req.parse_qs(req)["session_id"]
    user_id = authenticate_ws(req)
    {:cowboy_websocket, req, %{session_id: session_id, user_id: user_id, connected_at: now()}}
  end

  @doc """
  Se ejecuta cuando la conexión WebSocket se establece.
  """
  def websocket_init(state) do
    # Intentar obtener o crear sesión
    case ElPaso.Context.Manager.get_or_create_session(state.session_id, state.user_id) do
      {:ok, session_id, _session_state} ->
        new_state = %{state | session_id: session_id}
        # Enviar mensaje de bienvenida
        welcome_msg = %{
          type: "connected",
          session_id: session_id,
          user_id: state.user_id,
          timestamp: now()
        }

        {:reply, {:text, Jason.encode!(welcome_msg)}, new_state}

      _ ->
        # Continuar sin sesión válida
        {:ok, state}
    end
  end

  @doc """
  Maneja mensajes de texto recibidos del cliente.
  """
  def websocket_handle({:text, json}, state) do
    case Jason.decode(json) do
      {:ok, %{"type" => "chat", "messages" => messages} = params} ->
        handle_chat_request(messages, params, state)

      {:ok, %{"type" => "ping"}} ->
        # Responder al ping
        {:reply, {:text, ~s({"type":"pong","timestamp":#{now()}})}, state}

      {:ok, _other} ->
        error =
          Jason.encode!(%{
            error: %{
              message: "Unknown message type",
              type: "invalid_message_type"
            }
          })

        {:reply, {:text, error}, state}

      {:error, _reason} ->
        error =
          Jason.encode!(%{
            error: %{
              message: "Invalid JSON",
              type: "parse_error"
            }
          })

        {:reply, {:text, error}, state}
    end
  end

  # Maneja mensajes binarios (opcional)
  def websocket_handle({:binary, _data}, state) do
    {:ok, state}
  end

  # Maneja mensajes de info del proceso (enviados desde otro código)
  def websocket_info({:ws_chunk, chunk}, state) do
    {:reply, {:text, Jason.encode!(chunk)}, state}
  end

  def websocket_info(:done, state) do
    {:reply, {:text, ~s({"type":"done"})}, state}
  end

  def websocket_info({:broadcast, message}, state) do
    {:reply, {:text, Jason.encode!(message)}, state}
  end

  # Maneja cierre de conexión
  def websocket_terminate(_reason, _req, _state) do
    # Limpiar recursos si es necesario
    :ok
  end

  # Funciones privadas

  defp handle_chat_request(messages, params, state) do
    # Iniciar task para procesamiento asíncrono
    # Los chunks se enviarán via websocket_info
    task_ref = make_ref()

    Task.start(fn ->
      process_chat_stream(messages, params, state, task_ref)
    end)

    # Confirmar recepción y empezar streaming
    ack = %{
      type: "processing",
      request_id: inspect(task_ref),
      message_count: length(messages)
    }

    {:reply, {:text, Jason.encode!(ack)}, %{state | task_ref: task_ref}}
  end

  defp process_chat_stream(_messages, _params, _state, task_ref) do
    # Simular streaming de respuesta
    # En producción, esto invocaría el pipeline de inferencia

    # Enviar chunks de respuesta
    send(
      self(),
      {:ws_chunk,
       %{
         type: "chunk",
         content: "Procesando mensaje...",
         task_ref: inspect(task_ref)
       }}
    )

    # Simular delay
    Process.sleep(500)

    send(
      self(),
      {:ws_chunk,
       %{
         type: "chunk",
         content: "Respuesta streaming...",
         task_ref: inspect(task_ref)
       }}
    )

    # Señalar que terminó
    send(self(), :done)
  end

  defp authenticate_ws(req) do
    # Extraer API key del header Authorization
    case :cowboy_req.parse_header("authorization", req) do
      {<<"Bearer">>, api_key, _rest} ->
        case ElPaso.Security.Auth.authenticate(api_key) do
          {:ok, user_id} -> user_id
          {:error, _} -> "anonymous"
        end

      _ ->
        # Si no hay auth, permitir anónimo si está habilitado
        case ElPaso.Security.Auth.authenticate(nil) do
          {:ok, user_id} -> user_id
          {:error, _} -> nil
        end
    end
  end

  defp now do
    System.system_time(:second)
  end
end
