defmodule PlantClassifierWeb.Endpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :plant_classifier

  # Парсер для загрузки файлов
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug PlantClassifierWeb.Router
end
