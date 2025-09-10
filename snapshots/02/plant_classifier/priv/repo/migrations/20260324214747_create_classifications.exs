defmodule PlantClassifier.Repo.Migrations.CreateClassifications do
  use Ecto.Migration

  def change do
    create table(:classifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :image_path, :string
      add :top_label, :string
      add :top_label_ru, :string
      add :top_confidence, :float
      add :predictions, :map
      add :processing_time_ms, :integer
      add :status, :string, null: false, default: "pending"
      add :error, :string

      timestamps()
    end

    create index(:classifications, [:status])
    create index(:classifications, [:inserted_at])
  end
end