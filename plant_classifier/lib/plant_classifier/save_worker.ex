defmodule PlantClassifier.SaveWorker do
  @moduledoc false
  use Oban.Worker, queue: :save

  alias PlantClassifier.Repo
  alias PlantClassifier.Classification

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "classification_id" => id,
          "predictions" => predictions_data,
          "processing_time_ms" => time
        }
      }) do
    predictions =
      Enum.map(predictions_data, fn p ->
        %{
          label: p["label"],
          label_ru: p["label_ru"],
          score: p["score"],
          confidence: p["confidence"]
        }
      end)

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

    :ok
  end

  def perform(%Oban.Job{
        args: %{
          "classification_id" => id,
          "error" => error
        }
      }) do
    classification = Repo.get!(Classification, id)

    classification
    |> Classification.changeset(%{status: "error", error: error})
    |> Repo.update!()

    :ok
  end
end
