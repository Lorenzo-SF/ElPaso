defmodule ElPaso.HTTP do
  @moduledoc """
  Módulo HTTP del sistema.

  Este módulo implementa el servidor HTTP para las APIs REST del proyecto.
  """

  use Plug.Router

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor,
      restart: :permanent
    }
  end

  def start_link(_args) do
    Plug.Router.start(__MODULE__, [])
  end

  plug(:match)
  plug(:dispatch)

  # Endpoint para la inferencia
  get "/infer" do
    conn
    |> put_status(200)
    |> json(%{message: "Endpoint de inferencia"})
  end

  # Endpoint para el estado del modelo
  get "/models/status" do
    conn
    |> put_status(200)
    |> json(%{message: "Estado de los modelos"})
  end

  # Endpoint para el enrutamiento
  post "/route" do
    conn
    |> put_status(200)
    |> json(%{message: "Enrutamiento de solicitudes"})
  end

  defp json(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> resp(200, Jason.encode!(data))
  end
end
