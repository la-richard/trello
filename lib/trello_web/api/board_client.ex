defmodule TrelloWeb.BoardClient do
  use Tesla

  plug Tesla.Middleware.BaseUrl, "http://localhost:4000/api/boards"
  plug Tesla.Middleware.JSON

  def all() do
    get("/")
  end

  def user_boards(user_id) do
    get("/?user_id=#{user_id}")
  end

  def one(id) do
    get("/#{id}")
  end

  def create(user_id, board_params) do
    post("/", %{"user_id" => user_id, "board" => board_params})
  end
end
