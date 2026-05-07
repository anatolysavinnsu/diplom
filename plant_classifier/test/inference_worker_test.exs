defmodule PlantClassifier.InferenceWorkerTest do
  use ExUnit.Case

  alias PlantClassifier.InferenceWorker

  test "creates job with correct queue and args" do
    changeset = InferenceWorker.new(%{classification_id: "test-id"}, queue: :gpu)

    # Проверяем поля через Ecto.Changeset
    assert Ecto.Changeset.get_field(changeset, :queue) == "gpu"
    assert Ecto.Changeset.get_field(changeset, :args) == %{"classification_id" => "test-id"}
  end
end
