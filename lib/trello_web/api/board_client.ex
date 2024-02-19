defmodule TrelloWeb.BoardClient do
  use Tesla

  plug Tesla.Middleware.BaseUrl, "http://localhost:4000/api"
  plug Tesla.Middleware.JSON

  def new(token) do
    Tesla.client([{Tesla.Middleware.BearerAuth, token: token}])
  end

  def boards(client) do
    get(client, "/boards")
  end

  def user_boards(client, user_id) do
    get(client, "/boards?user_id=#{user_id}")
  end

  def one(client, id) do
    get(client, "/boards/#{id}")
  end

  def create(client, user_id, board_params) do
    post(client,"/boards", %{"user_id" => user_id, "board" => board_params})
  end

  def delete_board(client, board_id) do
    delete(client, "/boards/#{board_id}")
  end

  def board_lists(client, board_id) do
    get(client, "/boards/#{board_id}/lists")
  end

  def create_list(client, board_id, list_params) do
    post(client, "/boards/#{board_id}/lists", %{"board_id" => board_id, "list" => list_params})
  end

  def list_tasks(client, list_id) do
    get(client, "/lists/#{list_id}/tasks")
  end

  def create_task(client, list_id, user_id, task_params) do
    post(client, "/lists/#{list_id}/tasks", %{"reporter_id" => user_id, "task" => task_params})
  end

  def reorder_task(client, task_id, params) do
    put(client, "/tasks/#{task_id}/reorder", params)
  end

  def task(client, task_id) do
    get(client, "/tasks/#{task_id}")
  end

  def task_comments(client, task_id) do
    get(client, "/tasks/#{task_id}/comments")
  end

  def create_comment(client, task_id, creator_id, comment_params) do
    post(client, "/tasks/#{task_id}/comments", %{"creator_id" => creator_id, "comment" => comment_params})
  end

  def search_user(client, search_query) do
    get(client, "/users?search_query=#{search_query}")
  end

  def add_or_update_board_user(client, board_id, user_id, permission \\ :write) do
    put(client, "/boards/#{board_id}/users", %{"board_user" => %{"user_id" => user_id, "permission" => permission}})
  end

  def remove_board_user(client, board_id, user_id) do
    delete(client, "/boards/#{board_id}/users/#{user_id}")
  end

  def delete_list(client, list_id) do
    delete(client, "/lists/#{list_id}")
  end

  def get_board_user(client, board_id, user_id) do
    get(client, "/boards/#{board_id}/users/#{user_id}")
  end

  def update_task(client, task_id, task_params) do
    put(client, "/tasks/#{task_id}", %{"task" => task_params})
  end

  def delete_task(client, task_id) do
    delete(client, "/tasks/#{task_id}")
  end
end
