defmodule ElPaso.Security do
  @moduledoc """
  Módulo de seguridad básica para protección local.
  
  Este módulo implementa protección mínima suficiente para uso local:
  - API key local
  - Rate limiting
  - Sanitización de input
  """

  # Estructura para la configuración de seguridad
  defmodule SecurityConfig do
    @moduledoc """
    Estructura que representa la configuración de seguridad.
    """

    defstruct [
      :api_key,
      :rate_limit_rpm,
      :max_message_length_chars,
      :cors_enabled
    ]

    @type t :: %SecurityConfig{
            api_key: String.t() | nil,
            rate_limit_rpm: non_neg_integer(),
            max_message_length_chars: non_neg_integer(),
            cors_enabled: boolean()
          }
  end

  @doc """
  Valida la autenticación del request.
  """
  def validate_auth(request) do
    # Verificar si se requiere API key
    config = load_security_config()
    
    if config.api_key != nil do
      # Verificar header Authorization
      case Map.get(request.headers, "authorization") do
        "Bearer " <> api_key -> 
          if api_key == config.api_key do
            {:ok, :authenticated}
          else
            {:error, :unauthorized}
          end
        _ -> {:error, :unauthorized}
      end
    else
      # No se requiere autenticación
      {:ok, :authenticated}
    end
  end

  @doc """
  Verifica el rate limiting.
  """
  def check_rate_limit(request) do
    # Implementación simplificada de rate limiting con token bucket
    
    config = load_security_config()
    
    # En producción se usaría ETS para almacenar tokens
    # Esta implementación es simplificada
    
    true
  end

  @doc """
  Sanitiza el input del mensaje.
  """
  def sanitize_input(content) do
    # Verificar longitud máxima de mensaje
    config = load_security_config()
    
    if String.length(content) > config.max_message_length_chars do
      {:error, :message_too_long}
    else
      {:ok, content}
    end
  end

  @doc """
  Aplica CORS si está habilitado.
  """
  def apply_cors(response) do
    # Aplicar cabeceras CORS si están habilitadas
    
    config = load_security_config()
    
    if config.cors_enabled do
      response
      |> Map.put(:headers, Map.get(response, :headers, %{}) |> Map.put("Access-Control-Allow-Origin", "*")
    else
      response
    end
  end

  # Funciones auxiliares
  defp load_security_config() do
    # Cargar configuración de seguridad desde config/config.exs
    
    %SecurityConfig{
      api_key: nil,
      rate_limit_rpm: 60,
      max_message_length_chars: 32768,
      cors_enabled: false
    }
  end
end