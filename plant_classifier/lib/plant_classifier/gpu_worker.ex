defmodule PlantClassifier.GpuWorker do
  @moduledoc false
  use GenServer
  require Logger

  def start_link(name) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @impl true
  def init(_) do
    # Serving берём не из ETS, а через именованный :gpu_serving, поэтому в состоянии пусто
    send(self(), :process_next)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:process_next, state) do
    task = PlantClassifier.InternalQueue.pop()
    result = execute_task(task)
    dispatch_result(result)
    send(self(), :process_next)
    {:noreply, state}
  end

  defp execute_task(%{classification_id: id, file_path: file_path}) do
    start_time = System.monotonic_time()

    with {:ok, image} <- StbImage.read_file(file_path) do
      resized = StbImage.resize(image, 224, 224)

      # Вызываем batched_run на именованном сервисе
      results = Nx.Serving.batched_run(:gpu_serving, resized)

      duration = System.monotonic_time() - start_time
      duration_ms = System.convert_time_unit(duration, :native, :millisecond)

      predictions =
        results.predictions
        |> Enum.map(fn %{label: label, score: score} ->
          %{
            label: label,
            label_ru: translate_label(label),
            score: score,
            confidence: Float.round(score * 100, 2)
          }
        end)
        |> Enum.sort_by(& &1.score, :desc)
        |> Enum.take(3)

      {:ok, %{predictions: predictions, processing_time_ms: duration_ms, classification_id: id}}
    else
      {:error, reason} -> {:error, id, inspect(reason)}
    end
  end

  defp dispatch_result(
         {:ok, %{classification_id: id, predictions: predictions, processing_time_ms: time}}
       ) do
    predictions_data =
      Enum.map(predictions, fn p ->
        %{
          "label" => p.label,
          "label_ru" => p.label_ru,
          "score" => p.score,
          "confidence" => p.confidence
        }
      end)

    %{
      classification_id: id,
      predictions: predictions_data,
      processing_time_ms: time
    }
    |> PlantClassifier.SaveWorker.new(queue: :save)
    |> Oban.insert(repo: PlantClassifier.Repo)
  end

  defp dispatch_result({:error, id, error}) do
    %{
      classification_id: id,
      error: error
    }
    |> PlantClassifier.SaveWorker.new(queue: :save)
    |> Oban.insert(repo: PlantClassifier.Repo)
  end

  defp translate_label(label) do
    case label do
      "angular_leaf_spot" -> "Угловатая пятнистость листьев"
      "bean_rust" -> "Ржавчина фасоли"
      "healthy" -> "Здоровая"
      _ -> label
    end
  end
end
