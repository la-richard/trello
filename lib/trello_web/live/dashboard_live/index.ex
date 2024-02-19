defmodule TrelloWeb.DashboardLive.Index do
  use TrelloWeb, :live_view

  alias TrelloWeb.BoardClient

  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:api_client, BoardClient.new(session["access_token"]))
      |> fetch_boards()
      |> assign(:page_title, "Boards")

    {:ok, socket}
  end

  defp fetch_boards(socket) do
    %{current_user: %{"id" => user_id}, api_client: api_client} = socket.assigns
    case BoardClient.user_boards(api_client, user_id) do
      {:ok, response} ->
        case response.status do
          200 -> assign(socket, :boards, response.body["data"])
          403 -> push_navigate(socket, to: ~p"/login") # TODO: util function to return to this page after logging in
          _ -> assign(socket, :boards, [])
        end
      {:error, _} -> assign(socket, :boards, [])
    end
  end

  @spec handle_params(any(), any(), %{
          :assigns => atom() | %{:live_action => :create | :index, optional(any()) => any()},
          optional(any()) => any()
        }) :: {:noreply, map()}
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Boards")
  end

  defp apply_action(socket, :create, _params) do
    socket
    |> assign(:page_title, "Create board")
    |> assign(:form, to_form(%{"name" => "", "visibility" => :public}))
  end

  def handle_event("create_board", params, socket) do
    %{api_client: api_client, current_user: %{"id" => user_id}} = socket.assigns
    case BoardClient.create(api_client, user_id, params) do
      {:ok, response} ->
        case response.status do
          201 -> {:noreply, socket
            |> put_flash(:info, "Board successfully created!")
            |> fetch_boards()
            |> push_patch(to: ~p"/")}
          422 -> {:noreply, socket |> put_flash(:error, "Failed in creating new board") |> push_patch(to: ~p"/")}
          _ -> {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/")}
        end
      {:error, error} ->
        IO.inspect(error)
        {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/")}
    end
  end
end
