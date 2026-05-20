defmodule PlantClassifier.Vision do
  @moduledoc false
  require Logger

  def start_link do
    case :persistent_term.get(:model_serving, :not_loaded) do
      :not_loaded ->
        IO.puts("🔄 Загрузка модели nateraw/vit-base-beans...")
        start_time = System.monotonic_time(:millisecond)

        case load_model() do
          {:ok, serving} ->
            end_time = System.monotonic_time(:millisecond)
            IO.puts("✅ Модель загружена за #{end_time - start_time} мс")
            :persistent_term.put(:model_serving, serving)
            :ok

          {:error, reason} ->
            IO.puts("❌ Ошибка: #{reason}")
            {:error, reason}
        end

      _ ->
        IO.puts("✅ Модель уже загружена")
        :ok
    end
  end

  def classify(image_path) do
    IO.puts("🔍 Начинаем классификацию: #{image_path}")
    start = System.monotonic_time()
    serving = :persistent_term.get(:model_serving)

    IO.puts("📖 Читаем файл...")

    case StbImage.read_file(image_path) do
      {:ok, img} ->
        IO.puts("✅ Файл прочитан, делаем ресайз...")
        img = StbImage.resize(img, 224, 224)
        IO.puts("✅ Ресайз выполнен, запускаем инференс...")

        # Запускаем инференс с таймаутом
        task = Task.async(fn -> Nx.Serving.run(serving, img) end)

        case Task.yield(task, 60_000) || Task.shutdown(task) do
          {:ok, results} ->
            IO.puts("✅ Инференс завершен")

            duration = System.monotonic_time() - start
            duration_ms = System.convert_time_unit(duration, :native, :millisecond)

            predictions =
              results.predictions
              |> Enum.map(fn %{label: l, score: s} ->
                %{label: l, label_ru: translate(l), score: s, confidence: Float.round(s * 100, 2)}
              end)
              |> Enum.sort_by(& &1.score, :desc)
              |> Enum.take(3)

            %{
              success: true,
              predictions: predictions,
              top_prediction: hd(predictions),
              processing_time_ms: duration_ms
            }

          nil ->
            IO.puts("❌ Инференс завис, прервано по таймауту")
            %{success: false, error: "Инференс занял слишком много времени"}
        end

      {:error, reason} ->
        IO.puts("❌ Ошибка чтения файла: #{reason}")
        %{success: false, error: "Ошибка чтения: #{reason}"}
    end
  end

  defp load_model do
    try do
      {:ok, model} = Bumblebee.load_model({:hf, "nateraw/vit-base-beans"})
      {:ok, featurizer} = Bumblebee.load_featurizer({:hf, "nateraw/vit-base-beans"})
      {:ok, Bumblebee.Vision.image_classification(model, featurizer, compile: [batch_size: 1])}
    rescue
      e -> {:error, inspect(e)}
    end
  end

  defp translate("angular_leaf_spot"), do: "Угловатая пятнистость"
  defp translate("bean_rust"), do: "Ржавчина"
  defp translate("healthy"), do: "Здоровая"
  defp translate(l), do: l
end
