defmodule ElPaso.Engine.Dispatcher do
  @moduledoc """
  Punto de entrada único para inferencia.

  Este módulo coordina las llamadas a los distintos motores de inferencia,
  determinando qué modelo usar según el contexto.
  """

  alias ElPaso.Domain.ModelManager

  @doc """
  Envía una solicitud de inferencia al modelo adecuado.
  """
  def dispatch(request) do
    # Determinar qué modelo usar para la solicitud
    model_id = determine_model(request)

    # Enviar la solicitud al modelo
    ModelManager.infer(model_id, request)
  end

  defp determine_model(_request) do
    # Lógica de selección del modelo (simplificada)
    "default_model"
  end
end
