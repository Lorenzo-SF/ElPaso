defmodule ElPaso.HTTP.RequestParser do
  @moduledoc """
  Parser para requests HTTP de chat completions.
  
  Extrae los overrides de sesión del campo 'elpaso' en el request.
  """

  alias ElPaso.Context.Schemas.Message

  # Estructura para overrides de sesión
  defmodule SessionOverrides do
    @moduledoc """
    Estructura que representa los overrides de sesión.
    """

    defstruct [
      :session_id,
      :context_mode,
      :window_size,
      :force_model,
      :latency_tolerance_ms,
      :summarize_with_model
    ]

    @type t :: %SessionOverrides{
            session_id: String.t() | nil,
            context_mode: :transparent | :declarative | nil,
            window_size: non_neg_integer() | nil,
            force_model: String.t() | nil,
            latency_tolerance_ms: non_neg_integer() | nil,
            summarize_with_model: String.t() | nil
          }
  end

  @doc """
  Parsea un request de chat completions.
  """
  def parse_chat_request(body) do
    case Jason.decode(body) do
      {:ok, params} ->
        with {:ok, overrides} <- extract_elpaso_overrides(params),
               :ok <- validate_request(params) do
          {:ok, %{
            messages: params["messages"],
            model: params["model"] || "auto",
            stream: params["stream"] || false,
            temperature: params["temperature"],
            max_tokens: params["max_tokens"],
            session_id: overrides.session_id || params["user"],
            overrides: overrides
          }}
        else
          error -> error
        end
      {:error, _} -> {:error, :invalid_json}
    end
  end

  # Funciones auxiliares
  defp extract_elpaso_overrides(params) do
    ep = params["elpaso"] || %{}
    
    overrides = %SessionOverrides{
      session_id: ep["session_id"],
      context_mode: ep["context_mode"],
      window_size: ep["window_size"],
      force_model: ep["force_model"],
      latency_tolerance_ms: ep["latency_tolerance_ms"],
      summarize_with_model: ep["summarize_with_model"]
    }
    
    {:ok, overrides}
  end

  defp validate_request(params) do
    # Validación básica del request
    :ok
  end
end