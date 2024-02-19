defmodule TrelloWeb.UserClient do
  use Tesla

  plug Tesla.Middleware.BaseUrl, "http://localhost:4000/api"
  plug Tesla.Middleware.JSON

  def register(user_params) do
    post("/users", %{"user" => user_params})
  end

  def login(user_params) do
    post("/login", %{"user" => user_params})
  end

  def new(token) do
    Tesla.client([{Tesla.Middleware.BearerAuth, token: token}])
  end

  def verify(token) do
    get(new(token), "/users/verify")
  end

end
