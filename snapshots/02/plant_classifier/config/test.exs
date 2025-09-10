import Config

config :plant_classifier, PlantClassifier.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "plant_classifier_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :plant_classifier, Oban,
  queues: [gpu: 1, save: 1],
  plugins: [],
  testing: :manual
