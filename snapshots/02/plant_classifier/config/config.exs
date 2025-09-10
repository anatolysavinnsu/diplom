# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :plant_classifier,
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :plant_classifier, PlantClassifierWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: PlantClassifierWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PlantClassifier.PubSub,
  live_view: [signing_salt: "lx9+xcxb"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :plant_classifier, ecto_repos: [PlantClassifier.Repo]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
