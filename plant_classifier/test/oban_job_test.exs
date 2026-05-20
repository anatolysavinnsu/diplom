defmodule PlantClassifier.ObanJobTest do
  use ExUnit.Case

  alias PlantClassifier.InferenceWorker

  test "InferenceWorker job is created with correct queue and args" do
    changeset = InferenceWorker.new(%{classification_id: "test_id"}, queue: :gpu)

    assert Ecto.Changeset.get_field(changeset, :queue) == "gpu"
    assert Ecto.Changeset.get_field(changeset, :args) == %{classification_id: "test_id"}
  end
end
