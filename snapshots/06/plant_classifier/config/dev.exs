import Config

config :plant_classifier, PlantClassifierWeb.Endpoint,
  http: [port: 4000],
  debug_errors: false,
  code_reloader: false,
  check_origin: false,
  watchers: []

config :plant_classifier, PlantClassifier.Repo,
  username: "postgres",
  password: "postgres",
  database: "plant_classifier_dev",
  hostname: "localhost",
  timeout: 30_000,
  port: 5432,
  pool_size: 200,
  log: false

config :plant_classifier, Oban,
  repo: PlantClassifier.Repo,
  queues: [gpu: 200, save: 20],
  plugins: [Oban.Plugins.Pruner],
  log: false,
  dispatch_cooldown: 2

config :phoenix, :logger, false
config :nx, :default_defn_options, compiler: EXLA, async_threads: 4
