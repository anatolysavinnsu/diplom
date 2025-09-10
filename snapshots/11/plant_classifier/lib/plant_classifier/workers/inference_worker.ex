defmodule PlantClassifier.InferenceWorker do
  use Oban.Worker, queue: :gpu

  alias PlantClassifier.Repo
  alias PlantClassifier.Classification

  @shared_upload_path "priv/uploads"

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"classification_id" => id}}) do
    classification = Repo.get!(Classification, id)
    file_path = Path.join(@shared_upload_path, classification.filename)

    PlantClassifier.InternalQueue.push(%{
      classification_id: id,
      file_path: file_path
    })

    :ok
  end

  def update_classification(id, {:ok, %{predictions: predictions, processing_time_ms: time}}) do
    top = hd(predictions)

    predictions_map =
      predictions
      |> Enum.map(fn p ->
        {p.label,
         %{
           "label_ru" => p.label_ru,
           "score" => p.score,
           "confidence" => p.confidence
         }}
      end)
      |> Map.new()

    classification = Repo.get!(Classification, id)

    classification
    |> Classification.changeset(%{
      status: "completed",
      top_label: top.label,
      top_label_ru: top.label_ru,
      top_confidence: top.confidence,
      predictions: predictions_map,
      processing_time_ms: time
    })
    |> Repo.update!()
  end

  def update_classification(id, {:error, error}) do
    classification = Repo.get!(Classification, id)

    classification
    |> Classification.changeset(%{status: "error", error: inspect(error)})
    |> Repo.update!()
  end
end
