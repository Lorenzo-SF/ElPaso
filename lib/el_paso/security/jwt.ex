defmodule ElPaso.Security.JWT do
  @moduledoc """
  Módulo para generación y verificación de tokens JWT.
  """

  require Logger
  import Plug.Conn

  @ttl_hours 24

  @doc """
  Genera un token JWT para un usuario.

  ## Opciones
    - `user_id`: ID del usuario (required)
    - `role`: rol del usuario (:user, :admin). Default: :user

  ## Ejemplo
      iex> ElPaso.Security.JWT.generate_token("alice", :admin)
      "eyJhbGciOiJIUzI1NiJ9..."
  """
  @spec generate_token(String.t(), atom()) :: String.t()
  def generate_token(user_id, role \\ :user) do
    secret = get_secret()

    # Claims del token
    now = DateTime.utc_now()

    claims = %{
      "sub" => user_id,
      "role" => Atom.to_string(role),
      "iat" => DateTime.to_unix(now),
      "exp" => DateTime.to_unix(DateTime.add(now, @ttl_hours * 3600))
    }

    # Firmar con HS256
    case JOSE.JWT.sign(JOSE.JWK.from_oct(secret), %{"alg" => "HS256"}, claims) do
      {_, signed_jwt} ->
        JOSE.JWS.compact(signed_jwt)
        |> elem(1)

      error ->
        Logger.error("Error firmando JWT: #{inspect(error)}")
        raise "Error generando token"
    end
  end

  @doc """
  Verifica un token JWT y devuelve los claims.

  ## Respuesta
    - `{:ok, %{user_id: String.t(), role: atom()}}` si válido
    - `{:error, :expired}` si está expirado
    - `{:error, :invalid}` si es inválido
  """
  @spec verify_token(String.t()) :: {:ok, map()} | {:error, atom()}
  def verify_token(token) do
    secret = get_secret()

    case JOSE.JWT.verify(JOSE.JWK.from_oct(secret), token) do
      {true, jwt, _jws} ->
        claims = jwt.fields
        exp = claims["exp"]
        now = DateTime.to_unix(DateTime.utc_now())

        if now > exp do
          {:error, :expired}
        else
          {:ok,
           %{
             user_id: claims["sub"],
             role: String.to_atom(claims["role"])
           }}
        end

      {false, _, _} ->
        {:error, :invalid}

      error ->
        Logger.error("Error verificando JWT: #{inspect(error)}")
        {:error, :invalid}
    end
  end

  @doc """
  Extrae el token de una petición desde el header Authorization.
  Acepta formatos:
    - "Bearer <token>"
    - "<token>" (legacy)
  """
  @spec extract_from_conn(Plug.Conn.t()) :: String.t() | nil
  def extract_from_conn(conn) do
    # Intentar obtener del header Authorization
    case get_req_header(conn, "authorization") do
      [auth_header | _] ->
        # Quitar "Bearer " si existe
        Regex.replace(~r/^Bearer\s+/i, auth_header, "")

      _ ->
        nil
    end
  end

  # Obtener secret desde env o config.
  # En producción, EXIGE que ELPASO_JWT_SECRET esté configurado con un valor fuerte.
  defp get_secret do
    secret =
      System.get_env("ELPASO_JWT_SECRET") ||
        Application.get_env(:elpaso, :jwt_secret)

    # Lista negra de secrets inseguros (nunca permitir en producción)
    unsafe_defaults = [
      "dev-secret-change-in-prod",
      "change-me-in-production",
      "secret",
      "changeme"
    ]

    is_prod = Application.get_env(:elpaso, :env) == :prod || config_env_is_prod?()

    cond do
      is_nil(secret) and is_prod ->
        raise """
        ⚠️  ELPASO_JWT_SECRET debe estar configurado en producción.

        Añade a tu entorno:
          export ELPASO_JWT_SECRET="$(openssl rand -base64 64)"

        O en config/prod.exs:
          config :elpaso, jwt_secret: System.fetch_env!("ELPASO_JWT_SECRET")
        """

      is_nil(secret) ->
        # Desarrollo: generar un secret aleatorio para la sesión
        # Se almacena en Application env para ser consistente durante la ejecución
        Logger.warning("JWT secret no configurado. Generando secret temporal para desarrollo.")
        temp_secret = :crypto.strong_rand_bytes(32) |> Base.encode64()
        Application.put_env(:elpaso, :jwt_secret, temp_secret)
        temp_secret

      secret in unsafe_defaults and is_prod ->
        raise """
        ⚠️  ELPASO_JWT_SECRET usa un valor por defecto inseguro: "#{secret}"

        Genera un secret fuerte:
          openssl rand -base64 64
        """

      true ->
        secret
    end
  end

  defp config_env_is_prod? do
    case Application.get_env(:elpaso, :env) do
      :prod -> true
      _ -> false
    end
  end
end
