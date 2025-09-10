# test/test_helper.exs
Application.put_env(:plant_classifier, PlantClassifier.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "noop",
  hostname: "noop",
  pool_size: 1
)

Application.put_env(:plant_classifier, Oban,
  queues: [gpu: 1, save: 1],
  plugins: [],
  testing: :manual
)

ExUnit.start()
