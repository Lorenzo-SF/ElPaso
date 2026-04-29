defmodule ElPaso.Engine do
  @moduledoc """
  Behaviour público para engines de inferencia.

  Los engines pueden ser procesos locales (como Ollama) o APIs remotas.
  Este behaviour define la interfaz que todo engine debe implementar.
  """

  @doc "Nombre del engine, usado como identificador en config"
  @callback name() :: atom()

  @doc "Tipo del engine: local_process o remote_api"
  @callback type() :: :local_process | :remote_api

  @doc """
  Ejecuta inferencia y devuelve la respuesta completa.
  """
  @callback infer(
              prompt :: ElPaso.Context.Builder.BuiltPrompt.t(),
              params :: map(),
              config :: map()
            ) :: {:ok, ElPaso.Engine.Response.t()} | {:error, reason :: term()}

  @doc """
  Ejecuta inferencia en streaming, llamando callback por cada chunk.
  """
  @callback stream(
              prompt :: ElPaso.Context.Builder.BuiltPrompt.t(),
              params :: map(),
              config :: map(),
              chunk_callback :: (ElPaso.Engine.Chunk.t() -> :ok)
            ) :: :ok | {:error, reason :: term()}

  @doc """
  Adapta el PrefixBlock al formato que este engine espera.
  """
  @callback prepare_prefix(
              prefix :: ElPaso.Context.PrefixManager.PrefixBlock.t(),
              config :: map()
            ) :: term()

  @doc """
  Verifica que el engine está operativo.
  """
  @callback health_check(config :: map()) :: :ok | {:error, reason :: term()}

  @doc """
  Formatea la lista de mensajes al formato específico del engine.
  """
  @callback format_messages(
              messages :: [map()],
              context_spec :: map()
            ) :: term()

  # Funciones de ayuda para implementaciones

  defmacro __using__(_opts) do
    quote do
      @behaviour ElPaso.Engine
    end
  end
end

defmodule ElPaso.Engine.Response do
  @moduledoc """
  Estructura de respuesta de un engine de inferencia.
  """

  defstruct [
    :content,
    :finish_reason,
    :prompt_tokens,
    :completion_tokens,
    :latency_ms
  ]

  @type t :: %__MODULE__{
          content: String.t(),
          finish_reason: :stop | :length | :error,
          prompt_tokens: integer(),
          completion_tokens: integer(),
          latency_ms: integer()
        }
end

defmodule ElPaso.Engine.Chunk do
  @moduledoc """
  Estructura de chunk para streaming de inferencia.
  """

  defstruct [
    :content,
    :done,
    :tokens
  ]

  @type t :: %__MODULE__{
          content: String.t(),
          done: boolean(),
          tokens: integer() | nil
        }
end
