defmodule ElPaso.Examples.Pipeline do
  @moduledoc """
  Ejemplos de uso del pipeline de inferencia.

  Este módulo muestra cómo se usaría el pipeline en diferentes escenarios.
  """

  alias ElPaso.Pipeline
  alias ElPaso.Domain.Router

  @doc """
  Ejemplo básico de procesamiento de un request.

  ## Ejemplo

      iex> ElPaso.Examples.Pipeline.basic_example()
  """
  def basic_example do
    messages = [
      %{role: "user", content: "¿Cuál es la capital de Francia?"}
    ]

    options =
      %{
        # Opciones adicionales para el procesamiento
      }

    case Pipeline.process_request("req123", "sess456", messages, options) do
      {:ok, response} ->
        IO.puts("Respuesta: #{inspect(response)}")
        response

      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Ejemplo de streaming de respuesta.

  ## Ejemplo

      iex> ElPaso.Examples.Pipeline.streaming_example()
  """
  def streaming_example do
    messages = [
      %{role: "user", content: "Escribe un poema sobre el océano"}
    ]

    options = %{
      stream: true
      # Otras opciones de streaming
    }

    case Pipeline.stream_request("req123", "sess456", messages, options) do
      {:ok, response} ->
        IO.puts("Respuesta streaming: #{inspect(response)}")
        response

      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Ejemplo de selección de modelo con router.

  ## Ejemplo

      iex> ElPaso.Examples.Pipeline.router_example()
  """
  def router_example do
    messages = [
      %{role: "user", content: "Explica el concepto de machine learning"}
    ]

    case Router.select_model(messages, %{}) do
      {:ok, routing_decision} ->
        IO.puts("Decisión de enrutamiento: #{inspect(routing_decision)}")
        routing_decision

      {:error, reason} ->
        IO.puts("Error en router: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
