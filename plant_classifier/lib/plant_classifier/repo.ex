defmodule PlantClassifier.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :plant_classifier,
    adapter: Ecto.Adapters.Postgres
end
