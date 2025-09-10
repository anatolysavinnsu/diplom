defmodule PlantClassifier.Repo do
  use Ecto.Repo,
    otp_app: :plant_classifier,
    adapter: Ecto.Adapters.Postgres
end
