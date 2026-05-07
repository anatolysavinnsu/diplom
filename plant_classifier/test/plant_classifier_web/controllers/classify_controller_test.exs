defmodule PlantClassifierWeb.ClassifyControllerTest do
  use PlantClassifierWeb.ConnCase

  setup do
    # Убедимся, что Oban работает в тестовом режиме (ручной вызов)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PlantClassifier.Repo)
  end

  test "POST /api/classify returns job_id and creates classification", %{conn: conn} do
    path = Path.join(System.tmp_dir!(), "leaf.jpg")
    File.write!(path, "fake_image_data")

    upload = %Plug.Upload{
      path: path,
      content_type: "image/jpeg",
      filename: "leaf.jpg"
    }

    conn = post(conn, "/api/classify", %{image: upload})

    assert %{"success" => true, "job_id" => id} = json_response(conn, 200)
    assert is_binary(id)

    # Можно также проверить, что запись действительно создана в БД
    classification = PlantClassifier.Repo.get!(PlantClassifier.Classification, id)
    assert classification.status == "pending"
    assert classification.filename == "leaf.jpg"

    File.rm!(path)
  end

  test "GET /api/status/:id returns not found for missing id", %{conn: conn} do
    conn = get(conn, "/api/status/00000000-0000-0000-0000-000000000000")
    assert json_response(conn, 200) == %{"success" => false, "error" => "Задача не найдена"}
  end

  test "GET /api/history returns empty list initially", %{conn: conn} do
    conn = get(conn, "/api/history")
    assert %{"success" => true, "history" => []} == json_response(conn, 200)
  end
end
