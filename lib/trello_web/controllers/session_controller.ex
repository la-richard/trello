defmodule TrelloWeb.SessionController do
  use TrelloWeb, :controller

  alias TrelloWeb.Auth

  def login(conn, %{"user" => user_params}) do
    Auth.login_user(conn, user_params)
  end

  def logout(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> Auth.logout_user()
  end

end
