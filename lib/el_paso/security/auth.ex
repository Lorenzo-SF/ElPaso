defmodule ElPaso.Security.Auth do
  @moduledoc """
  Autenticación de requests por API key.

  Busca usuarios en la tabla `users` de PostgreSQL (vía Ecto).
  Soporta también una API key global como fallback para desarrollo.
  """

  alias ElPaso.Repo
  alias ElPaso.Models.User
  import Ecto.Query

  @doc """
  Autentica un request por su API key. Devuelve {:ok, user_id} si es válido.
  """
  def authenticate(api_key) do
    config =
      ElPaso.Config.Loader.get()
      |> case do
        {:ok, c} -> c
        {:error, _} -> %{}
      end

    auth_enabled = get_in(config, [:auth, :enabled]) || false
    allow_anonymous = get_in(config, [:auth, :allow_anonymous]) || true

    cond do
      not auth_enabled ->
        {:ok, "anonymous"}

      is_nil(api_key) and allow_anonymous ->
        {:ok, "anonymous"}

      is_nil(api_key) ->
        {:error, :missing_api_key}

      true ->
        # Buscar en base de datos primero
        case find_user_in_db(api_key) do
          %User{id: user_id, active: true} ->
            {:ok, user_id}

          %User{active: false} ->
            {:error, :user_inactive}

          nil ->
            # Fallback: API key global (para desarrollo)
            global_key = Application.get_env(:elpaso, :inference_api_key)

            if api_key == global_key do
              {:ok, "admin"}
            else
              {:error, :invalid_api_key}
            end
        end
    end
  end

  @doc """
  Verifica si una API key es válida para generar token JWT en /auth/token.
  """
  def valid_api_key?(api_key) do
    case find_user_in_db(api_key) do
      %User{active: true} ->
        true

      _ ->
        # Fallback global key
        api_key == Application.get_env(:elpaso, :inference_api_key)
    end
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

  # ── Private ──────────────────────────────────────────────────

  defp find_user_in_db(api_key) do
    # La API key se almacena hasheada. Comparamos con hash SHA256.
    # NOTA: Si las API keys no están hasheadas aún, busca directa.
    # Para migración gradual: intentar ambos.
    api_key_hash = :crypto.hash(:sha256, api_key) |> Base.encode16(case: :lower)

    Repo.one(
      from(u in User,
        where: u.api_key_hash == ^api_key_hash,
        or_where: u.api_key_hash == ^api_key
      )
    )
  rescue
    _ -> nil
  end
end
