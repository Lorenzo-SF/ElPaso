defmodule ElPaso.HTTP.Server do
  @moduledoc """
  Servidor HTTP para las APIs REST del proyecto.
  
  Este módulo implementa el servidor HTTP usando Plug y Cowboy para exponer
  los endpoints necesarios del proxy de inferencia.
  """

  use Plug.Router

  plug :match
  plug :dispatch

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