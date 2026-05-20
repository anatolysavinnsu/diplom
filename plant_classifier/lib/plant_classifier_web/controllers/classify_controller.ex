defmodule PlantClassifierWeb.ClassifyController do
  @moduledoc false
  use PlantClassifierWeb, :controller
  alias PlantClassifier.Repo
  alias PlantClassifier.Classification
  # ← добавляем импорт
  import Ecto.Query

  def classify(conn, %{"image" => %Plug.Upload{path: temp_path, filename: filename}}) do
    IO.puts("📸 Обработка: #{filename}")

    {:ok, classification} =
      %Classification{}
      |> Classification.changeset(%{
        filename: filename,
        status: "pending"
      })
      |> Repo.insert()

    IO.puts("✅ Запись создана: #{classification.id}")

    # Сразу создаём задачу для инференса, минуя PreprocessWorker
    %{classification_id: classification.id}
    |> PlantClassifier.InferenceWorker.new(queue: :gpu)
    |> Oban.insert(repo: PlantClassifier.Repo)

    json(conn, %{
      success: true,
      job_id: classification.id,
      status: "pending",
      message: "Изображение поставлено в очередь обработки"
    })
  end

  def classify(conn, _params) do
    json(conn, %{success: false, error: "Файл не загружен"})
  end

  def status(conn, %{"id" => id}) do
    case Repo.get(Classification, id) do
      nil ->
        json(conn, %{success: false, error: "Задача не найдена"})

      classification ->
        predictions_list =
          if classification.predictions do
            Enum.map(classification.predictions, fn {label, data} ->
              %{
                label: label,
                label_ru: data["label_ru"],
                score: data["score"],
                confidence: data["confidence"]
              }
            end)
            |> Enum.sort_by(& &1.score, :desc)
          else
            []
          end

        json(conn, %{
          success: true,
          status: classification.status,
          result:
            if classification.status == "completed" do
              %{
                filename: classification.filename,
                top_label_ru: classification.top_label_ru,
                top_confidence: classification.top_confidence,
                predictions: predictions_list,
                processing_time_ms: classification.processing_time_ms
              }
            end,
          error: classification.error
        })
    end
  end

  # Новый эндпоинт для истории
  def history(conn, _params) do
    classifications =
      Repo.all(
        from(c in Classification,
          where: c.status == "completed",
          order_by: [desc: c.inserted_at],
          limit: 20
        )
      )

    history =
      Enum.map(classifications, fn c ->
        %{
          id: c.id,
          filename: c.filename,
          top_label_ru: c.top_label_ru,
          top_confidence: c.top_confidence,
          processing_time_ms: c.processing_time_ms,
          inserted_at: c.inserted_at
        }
      end)

    json(conn, %{success: true, history: history})
  end

  def nodes(conn, _params) do
    nodes = Node.list() |> Enum.map(&to_string/1)
    json(conn, %{success: true, nodes: nodes, self: to_string(Node.self())})
  end

  def cluster_info(conn, _params) do
    connected_nodes = Node.list() |> Enum.map(&to_string/1)

    json(conn, %{
      success: true,
      current_node: Node.self() |> to_string(),
      connected_nodes: connected_nodes,
      gpu_available: PlantClassifier.GpuMonitor.available?(),
      node_role: System.get_env("NODE_ROLE") || "web",
      # +1 это текущий узел
      cluster_size: length(connected_nodes) + 1
    })
  end

  def add_node(conn, %{"node_name" => node_name}) do
    node_atom = String.to_atom(node_name)

    result =
      case Node.connect(node_atom) do
        true ->
          %{success: true, message: "Узел #{node_name} успешно подключён"}

        false ->
          %{success: false, error: "Не удалось подключить узел #{node_name}"}
      end

    json(conn, result)
  end

  def disconnect_node(conn, %{"node_name" => node_name}) do
    node_atom = String.to_atom(node_name)

    result =
      case Node.disconnect(node_atom) do
        true ->
          %{success: true, message: "Узел #{node_name} отключён"}

        false ->
          %{success: false, error: "Не удалось отключить узел #{node_name}"}
      end

    json(conn, result)
  end
end
