defmodule PlantClassifier.ModelManager do
  use GenServer
  require Logger

  @model_repo "nateraw/vit-base-beans"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    setup_backend()
    Logger.info("🔄 Загружаю модель #{@model_repo}...")

    with {:ok, model} <- Bumblebee.load_model({:hf, @model_repo}),
         {:ok, featurizer} <- Bumblebee.load_featurizer({:hf, @model_repo}) do
      serving =
        Bumblebee.Vision.image_classification(model, featurizer,
          compile: [batch_size: 8],
          defn_options: [compiler: EXLA]
        )

      # Запускаем Nx.Serving с динамическим батчингом
      {:ok, _pid} =
        Nx.Serving.start_link(
          serving: serving,
          name: :gpu_serving,
          batch_size: 8,
          batch_timeout: 50
        )

      Logger.info("✅ Модель и батчинговый сервер готовы!")
      {:ok, %{serving: serving}}
    else
      {:error, reason} ->
        Logger.error("❌ Ошибка загрузки: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  defp setup_backend do
    try do
      Nx.global_default_backend(EXLA.Backend)
      Nx.Defn.default_options(compiler: EXLA, async_threads: 4)
      Logger.info("✅ EXLA backend + 4 async threads")
    rescue
      _ -> Logger.info("ℹ️ CPU backend")
    end
  end
end
