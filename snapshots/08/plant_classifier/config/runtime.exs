import Config

# Определяем роль узла из переменной окружения NODE_ROLE
node_role = System.get_env("NODE_ROLE") || "web"

if System.get_env("EXLA_CLIENT") == "cuda" do
  config :nx, default_backend: EXLA.Backend

  config :exla, :clients,
    cuda: [
      platform: :cuda,
      preallocate: false,
      memory_fraction: 0.8
    ]

  config :exla, default_client: :cuda
end

if System.get_env("NODE_ROLE") == "gpu" do
  config :plant_classifier, PlantClassifierWeb.Endpoint, server: false

  config :plant_classifier, Oban, queues: [gpu: 20]
end

oban_queues =
  case System.get_env("OBAN_QUEUES") do
    nil ->
      [preprocess: 10, gpu: 5, save: 10]

    queues_str ->
      queues_str
      |> String.split()
      |> Enum.map(fn item ->
        [queue, limit] = String.split(item, ",")
        {String.to_atom(queue), String.to_integer(limit)}
      end)
  end

config :plant_classifier, Oban,
  repo: PlantClassifier.Repo,
  queues: oban_queues,
  plugins: [Oban.Plugins.Pruner],
  log: false
