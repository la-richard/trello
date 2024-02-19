defmodule TrelloWeb.Auth do
  use TrelloWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias TrelloWeb.UserClient

  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_trello_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  def login_user(conn, params) do
    case UserClient.login(params) do
      {:ok, response} ->
        case response.status do
          200 ->
            %{"token" => token} = response.body["data"]
            user_return_to = get_session(conn, :user_return_to)

            conn
            |> renew_session()
            |> put_token_in_session(token)
            |> maybe_write_remember_me_cookie(token, params)
            |> put_flash(:info, "Successfully logged in!")
            |> redirect(to: user_return_to || signed_in_path(conn))
          422 ->
            conn
              |> put_flash(:error, "Invalid email or password.")
              |> redirect(to: ~p"/login")
          403 ->
            conn
              |> put_flash(:error, "Invalid email or password.")
              |> redirect(to: ~p"/login")
          _ ->
            conn
              |> put_flash(:error, "Something went wrong! Try again later.")
              |> redirect(to: ~p"/login")
        end
      {:error, _} ->
        conn
          |> put_flash(:error, "Something went wrong! Try again later.")
          |> redirect(to: ~p"/login")
    end
  end

  def logout_user(conn) do
    if live_socket_id = get_session(conn, :live_socket_id) do
      TrelloWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/login")
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: "/login")
      |> halt()
    end
  end

  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  def fetch_current_user(conn, _opts) do
    {access_token, conn} = ensure_user_token(conn)
    case UserClient.verify(access_token) do
      {:ok, response} ->
        if response.status == 200 do
          assign(conn, :current_user, response.body["data"])
        else
          assign(conn, :current_user, nil)
        end
      {:error, _} -> assign(conn, :current_user, nil)
    end
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :access_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be logged in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/login")
      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if access_token = session["access_token"] do
        case UserClient.verify(access_token) do
          {:ok, response} ->
            if response.status == 200, do: response.body["data"], else: nil
          {:error, _} -> nil
        end
      end
    end)
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:access_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp signed_in_path(_conn), do: ~p"/"

  def maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  def maybe_store_return_to(conn), do: conn

end
