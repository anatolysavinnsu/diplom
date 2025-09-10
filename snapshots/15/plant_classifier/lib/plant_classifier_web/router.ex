defmodule PlantClassifierWeb.Router do
  use PlantClassifierWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PlantClassifierWeb do
    pipe_through :browser
    get "/", PageController, :index
  end

  scope "/api", PlantClassifierWeb do
    pipe_through :api
    post "/classify", ClassifyController, :classify
    # ← ДОБАВЬ ЭТУ СТРОКУ
    get "/status/:id", ClassifyController, :status
    # новый маршрут
    get "/history", ClassifyController, :history
    get "/nodes", ClassifyController, :nodes
    # ← добавить
    get "/cluster_info", ClassifyController, :cluster_info
    # ← добавить
    post "/add_node", ClassifyController, :add_node
    # ← добавить
    post "/disconnect_node", ClassifyController, :disconnect_node
  end
end
