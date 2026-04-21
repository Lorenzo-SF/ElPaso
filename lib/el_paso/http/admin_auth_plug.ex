defmodule ElPaso.HTTP.AdminAuthPlug do
  @moduledoc """
  Plug para verificar que el usuario tiene rol :admin.
  Se usa en los endpoints /admin/*.
  """

  import Plug.Conn
  import ElPaso.Security.JWT

  def init(opts), do: opts

  def call(conn, _opts) do
    # Extraer token del header Authorization
    token = extract_token(conn)

    case verify_token(token) do
      {:ok, %{role: :admin}} ->
        # Admin permitido
        assign(conn, :current_user, token.user_id)

      {:ok, %{role: _role}} ->
        # Otros roles no permitidos
        conn
        |> put_status(403)
        |> halt()

      {:error, _reason} ->
        conn
        |> put_status(401)
        |> halt()
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      [auth_header] ->
        # Quitar "Bearer " si existe
        String.replace(auth_header, ~r/^Bearer\s+/i, "")

      _ ->
        nil
    end
  end
end
