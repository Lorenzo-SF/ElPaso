defmodule ElPaso.Context.PrefixManager do
  @moduledoc """
  Gestor del bloque canónico de prompt compartido.

  Este módulo es responsable de construir y gestionar el bloque canónico que se coloca
  siempre al inicio de cada prompt enviado a cualquier motor de inferencia. Este bloque está diseñado
  para maximizar los beneficios del KV cache de los motores de inferencia.
  """

  use GenServer

  # Estructura para el bloque canónico
  defmodule PrefixBlock do
    @moduledoc """
    Estructura que representa un bloque canónico de prompt.
    """

    defstruct [
      :session_id,
      :content,
      :hash,
      :token_estimate,
      :built_at,
      :version
    ]

    @type t :: %__MODULE__{
            session_id: String.t(),
            content: String.t(),
            hash: binary(),
            token_estimate: non_neg_integer(),
            built_at: DateTime.t(),
            version: non_neg_integer()
          }
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(_args) do
    # Inicializar ETS para almacenar bloques canónicos
    prefix_table = :ets.new(:prefix_blocks, [:named_table, :protected, :set])
    {:ok, %{table: prefix_table}}
  end

  @doc """
  Obtiene el bloque canónico para una sesión.
  """
  def get(session_id) do
    case :ets.lookup(:prefix_blocks, session_id) do
      [] -> {:error, :not_found}
      [{_session_id, prefix_block}] -> {:ok, prefix_block}
    end
  end

  @doc """
  Construye el bloque canónico para una sesión.
  """
  def build(session_id, config) do
    # Construir el contenido del bloque canónico basado en la configuración
    content = build_prefix_content(config)

    # Calcular hash SHA256
    hash = :crypto.hash(:sha256, content)

    # Estimar tokens
    token_estimate = estimate_tokens(content)

    # Crear el bloque
    prefix_block = %PrefixBlock{
      session_id: session_id,
      content: content,
      hash: hash,
      token_estimate: token_estimate,
      built_at: DateTime.utc_now(),
      version: 1
    }

    # Guardar en ETS
    :ets.insert(:prefix_blocks, {session_id, prefix_block})

    {:ok, prefix_block}
  end

  @doc """
  Invalida el bloque canónico para una sesión.
  """
  def invalidate(session_id) do
    :ets.delete(:prefix_blocks, session_id)
    :ok
  end

  @doc """
  Obtiene el hash del bloque canónico para una sesión.
  """
  def hash(session_id) do
    case :ets.lookup(:prefix_blocks, session_id) do
      [] -> {:error, :not_found}
      [{_session_id, prefix_block}] -> {:ok, prefix_block.hash}
    end
  end

  # Funciones auxiliares
  defp build_prefix_content(config) do
    # Sección 1: System prompt base
    system_prompt = Map.get(config, :system_prompt, "Eres un asistente útil y preciso.")

    # Sección 2: Perfil de capacidades (opcional)
    capabilities = Map.get(config, :capabilities, "")

    # Sección 3: Documentos de referencia fijos (opcional)
    references = Map.get(config, :references, [])

    # Construir lista de secciones no vacías
    sections =
      [system_prompt]
      |> maybe_add(capabilities != "", capabilities)
      |> maybe_add(references != [], Enum.join(references, "\n"))

    # Añadir separador y unir
    sections
    |> Enum.concat(["---BEGIN DYNAMIC CONTEXT---"])
    |> Enum.join("\n")
  end

  defp maybe_add(list, true, value), do: list ++ [value]
  defp maybe_add(list, false, _), do: list

  defp estimate_tokens(content) do
    # Estimación simple basada en caracteres (3 caracteres ≈ 1 token)
    div(String.length(content), 3)
  end
end
