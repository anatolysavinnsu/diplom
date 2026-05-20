defmodule PlantClassifier.SaveWorkerTest do
  use ExUnit.Case

  alias PlantClassifier.SaveWorker

  test "SaveWorker job is created with correct args" do
    changeset =
      SaveWorker.new(
        %{
          classification_id: "id",
          predictions: [
            %{
              "label" => "healthy",
              "label_ru" => "Здоровая",
              "score" => 0.95,
              "confidence" => 95.0
            }
          ],
          processing_time_ms: 100
        },
        queue: :save
      )

    assert Ecto.Changeset.get_field(changeset, :queue) == "save"

    assert Ecto.Changeset.get_field(changeset, :args) == %{
             classification_id: "id",
             predictions: [
               %{
                 "label" => "healthy",
                 "label_ru" => "Здоровая",
                 "score" => 0.95,
                 "confidence" => 95.0
               }
             ],
             processing_time_ms: 100
           }
  end
end
