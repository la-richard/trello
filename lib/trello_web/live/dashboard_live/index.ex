defmodule TrelloWeb.DashboardLive.Index do
  use TrelloWeb, :live_view

  alias TrelloWeb.BoardClient

  def mount(_params, _session, socket) do
    socket =
      socket
      |> fetch_boards()
      |> assign(:page_title, "Boards")

    {:ok, socket}
  end

  defp fetch_boards(socket) do
    case BoardClient.boards() do
      {:ok, response} -> socket |> assign(:boards, response.body["data"])
      {:error, _} -> socket
    end
  end

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
    case BoardClient.create("b093bd77-084a-499f-a77b-845eca0a718b", params) do
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
