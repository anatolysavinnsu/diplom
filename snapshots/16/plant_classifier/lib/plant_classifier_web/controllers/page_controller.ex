defmodule PlantClassifierWeb.PageController do
  use PlantClassifierWeb, :controller

  def index(conn, _params) do
    file_path = Path.join(:code.priv_dir(:plant_classifier), "static/index.html")

    case File.read(file_path) do
      {:ok, html} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, html)

      {:error, _} ->
        send_resp(conn, 404, "Page not found")
    end
  end
end
