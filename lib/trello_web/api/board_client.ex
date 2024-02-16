defmodule TrelloWeb.BoardClient do
  use Tesla

  plug Tesla.Middleware.BaseUrl, "http://localhost:4000/api"
  plug Tesla.Middleware.JSON

  def boards() do
    get("/boards")
  end

  def user_boards(user_id) do
    get("/boards?user_id=#{user_id}")
  end

  def one(id) do
    get("/boards/#{id}")
  end

  def create(user_id, board_params) do
    post("/boards", %{"user_id" => user_id, "board" => board_params})
  end

  def create_list(board_id, list_params) do
    post("/boards/#{board_id}/lists", %{"board_id" => board_id, "list" => list_params})
  end

  def create_task(list_id, user_id, task_params) do
    post("/lists/#{list_id}/tasks", %{"reporter_id" => user_id, "task" => task_params})
  end
end
