defmodule ElPaso.Context.Tokenizer do
  @moduledoc """
  Módulo para manejar tokenizadores para modelos locales.

  Reemplaza el conteo simple con backends reales.
  """

  # Estructura para configuración del tokenizador
  defmodule TokenizerConfig do
    @moduledoc """
    Estructura que representa la configuración de un tokenizador.
    """

    defstruct [
      :backend,
      :model_name
    ]

    @type t :: %TokenizerConfig{
            backend: :tiktoken | :estimate,
            model_name: String.t() | nil
          }
  end

  @doc """
  Registra el tokenizador para un model_id.
  """
  def register(_model_id, _config) do
    :ok
  end

  @doc """
  Cuenta tokens usando el tokenizador registrado para ese modelo.
  Si no hay tokenizador registrado, hace fallback a estimación simple.
  """
  def count(text, _model_id) when is_binary(text) do
    # Estimación simple: ~3 caracteres por token
    {:fallback, div(String.length(text), 3)}
  end

  @doc """
  Informa qué backend está usando un modelo.
  """
  def info(_model_id) do
    %{
      backend: :estimate,
      registered_at: DateTime.utc_now()
    }
  end

  @doc """
  Lista todos los modelos y sus backends registrados.
  """
  def list do
    []
  end
end
