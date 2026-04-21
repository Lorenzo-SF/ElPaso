defmodule ElPaso.Security.Auth do
  @doc """
  Autentica un request por su API key. Devuelve el user_id si es válido.
  """
  def authenticate(api_key) do
    auth_config = ElPaso.Config.Loader.get().auth
    # Dynamic access to avoid static typing warning for stub config
    enabled = Map.get(auth_config, :enabled, false)
    allow_anonymous = Map.get(auth_config, :allow_anonymous, true)
    users = Map.get(auth_config, :users, [])

    cond do
      not enabled ->
        {:ok, "anonymous"}

      api_key == nil and allow_anonymous ->
        {:ok, "anonymous"}

      api_key == nil ->
        {:error, :missing_api_key}

      true ->
        case find_user_by_key(users, api_key) do
          nil -> {:error, :invalid_api_key}
          user -> {:ok, user.id}
        end
    end
  end

  @doc """
  Verifica si una API key es válida para /auth/token.
  """
  def valid_api_key?(api_key) do
    auth_config = ElPaso.Config.Loader.get().auth
    users = Map.get(auth_config, :users, [])

    # Verificar en la lista de usuarios o usar API key global
    find_user_by_key(users, api_key) != nil or
      api_key == Application.get_env(:elpaso, :inference_api_key)
  end

  @doc """
  Extrae la API key del header Authorization: Bearer <key>
  """
  def extract_api_key(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> key] -> key
      _ -> nil
    end
  end

  defp find_user_by_key(users, api_key) do
    Enum.find(users, fn u -> u.api_key == api_key end)
  end
end
