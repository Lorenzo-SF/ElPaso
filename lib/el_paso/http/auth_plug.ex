defmodule ElPaso.HTTP.AuthPlug do
  @behaviour Plug

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    api_key = ElPaso.Security.Auth.extract_api_key(conn)

    case ElPaso.Security.Auth.authenticate(api_key) do
      {:ok, user_id} ->
        conn |> assign(:current_user_id, user_id)

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          401,
          Jason.encode!(%{
            error: %{
              message: auth_error_message(reason),
              type: "authentication_error",
              code: "elpaso_401"
            }
          })
        )
        |> halt()
    end
  end

  defp auth_error_message(:missing_api_key), do: "API key is required"
  defp auth_error_message(:invalid_api_key), do: "Invalid API key"
  defp auth_error_message(_), do: "Authentication failed"
end
