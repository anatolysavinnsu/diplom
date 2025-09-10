defmodule PlantClassifier.Application do
  use Application

  @impl true
  def start(_type, _args) do
    Application.ensure_all_started(:exla)
    Application.ensure_all_started(:bumblebee)
    Application.ensure_all_started(:stb_image)

    oban_config = Application.get_env(:plant_classifier, Oban)
    cluster_topologies = Application.get_env(:libcluster, :topologies, [])

    # пул GPU-воркеров
    children =
      [
        PlantClassifier.Repo,
        # загружает модель в ETS
        PlantClassifier.ModelManager,
        # очередь gpu (диспетчеры)
        {Oban, oban_config},
        # быстрая in-memory очередь
        PlantClassifier.InternalQueue,
        {Cluster.Supervisor, [cluster_topologies, [name: PlantClassifier.ClusterSupervisor]]},
        PlantClassifierWeb.Endpoint
      ] ++
        for i <- 1..4 do
          %{
            id: :"gpu_worker_#{i}",
            start: {PlantClassifier.GpuWorker, :start_link, [:"gpu_worker_#{i}"]},
            restart: :permanent
          }
        end

    opts = [strategy: :one_for_one, name: PlantClassifier.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PlantClassifierWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
