defmodule ElPaso.Engine.Base do
  @moduledoc """
  Behaviour base para los motores de inferencia.
  
  Este módulo define las interfaces comunes para todos los motores de inferencia compatibles con ElPaso.
  """

  alias ElPaso.Context.Builder

  @doc """
  Interface pública para ejecutar una inferencia.
  """
  @callback infer(model_id, prompt, opts) :: {:ok, response} | {:error, reason}

  @doc """
  Preparación del bloque canónico para el motor específico.
  """
  @callback prepare_prefix(prefix_block, model_config) :: {:ok, prepared_prefix} | {:error, reason}

  @doc """
  Interface para obtener información del modelo.
  """
  @callback get_model_info(model_id) :: {:ok, model_info} | {:error, reason}

  @doc """
  Interface para verificar si el modelo está disponible.
  """
  @callback is_available?(model_id) :: boolean()

  @doc """
  Interface para arrancar un modelo.
  """
  @callback start_model(model_id, opts) :: {:ok, pid} | {:error, reason}

  @doc """
  Interface para detener un modelo.
  """
  @callback stop_model(model_id) :: :ok | {:error, reason}
end