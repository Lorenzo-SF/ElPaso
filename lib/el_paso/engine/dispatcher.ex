defmodule ElPaso.Engine.Dispatcher do
  @moduledoc """
  Punto de entrada único para inferencia.

  Este módulo coordina las llamadas a los distintos motores de inferencia,
  integrando el Router para selección automática del mejor modelo.
  """

  alias ElPaso.Domain.{Router, ModelManager}
  require Logger

  @doc """
  Envía una solicitud de inferencia al modelo adecuado.

  ## Parámetros
    - `request`: mapa con `:messages` (obligatorio) y opcionalmente `:model_hint`

  ## Retorno
    - `{:ok, response}` — inferencia exitosa
    - `{:error, reason}` — error

  ## Ejemplo
      Dispatcher.dispatch(%{
        messages: [%{role: "user", content: "Escribe código para ordenar una lista"}],
        model_hint: "auto"
      })
  """
  @spec dispatch(map()) :: {:ok, map()} | {:error, term()}
  def dispatch(request) do
    messages = extract_messages(request)

    # Seleccionar modelo vía router, respetando model_hint si se especifica
    model_name =
      case Map.get(request, :model_hint) do
        hint when hint in [nil, "", "auto"] ->
          case Router.select_model(messages, %{}) do
            {:ok, %{model_name: name}} ->
              Logger.info("[Dispatcher] Router selected model: #{name}")
              name

            {:error, reason} ->
              Logger.error("[Dispatcher] Router failed: #{inspect(reason)}")
              nil
          end

        explicit_model ->
          Logger.info("[Dispatcher] Using explicit model: #{explicit_model}")
          explicit_model
      end

    if is_nil(model_name) do
      {:error, %{type: :no_model_available, message: "No active model available for inference"}}
    else
      ModelManager.infer(model_name, build_infer_request(request, model_name))
    end
  end

  # ── Private ──────────────────────────────────────────────────

  defp extract_messages(%{messages: msgs}) when is_list(msgs), do: msgs
  defp extract_messages(%{"messages" => msgs}) when is_list(msgs), do: msgs
  defp extract_messages(_), do: []

  defp build_infer_request(request, model_name) do
    %{
      messages: extract_messages(request),
      model_hint: model_name,
      temperature: Map.get(request, :temperature),
      max_tokens: Map.get(request, :max_tokens)
    }
  end
end
