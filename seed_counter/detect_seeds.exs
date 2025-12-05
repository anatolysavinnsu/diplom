Nx.global_default_backend(EXLA.Backend)

{:ok, model_info} = Bumblebee.load_model({:hf, "nateraw/vit-base-beans"})
{:ok, featurizer} = Bumblebee.load_featurizer({:hf, "nateraw/vit-base-beans"})

serving = Bumblebee.Vision.image_classification(model_info, featurizer)

image_path = "img_2.png"
{:ok, image} = StbImage.read_file(image_path)
result = Nx.Serving.run(serving, image)

IO.puts("Топ-5 предсказаний для изображения:")
Enum.each(result.predictions, fn %{label: label, score: score} ->
  IO.puts("  #{label}: #{Float.round(score, 5)}")
end)