defmodule PlantClassifier.Classification do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "classifications" do
    field(:filename, :string)
    field(:image_path, :string)
    field(:top_label, :string)
    field(:top_label_ru, :string)
    field(:top_confidence, :float)
    field(:predictions, :map)
    field(:processing_time_ms, :integer)
    field(:status, :string, default: "pending")
    field(:error, :string)

    timestamps()
  end

  def changeset(classification, attrs) do
    classification
    |> cast(attrs, [
      :filename,
      :image_path,
      :top_label,
      :top_label_ru,
      :top_confidence,
      :predictions,
      :processing_time_ms,
      :status,
      :error
    ])
    |> validate_required([:filename, :status])
  end
end
