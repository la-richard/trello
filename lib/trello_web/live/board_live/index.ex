defmodule TrelloWeb.BoardLive.Index do
  use TrelloWeb, :live_view

  alias TrelloWeb.BoardClient

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, %{"board_id" => board_id}) do
    fetch_board(socket, board_id)
  end

  defp apply_action(socket, :create_list, _params) do
    socket
    |> assign(:page_title, "Create list")
    |> assign(:form, to_form(%{"name" => ""}))
  end

  defp apply_action(socket, :create_task, %{"list_id" => list_id}) do
    socket
    |> assign(:page_title, "Create task")
    |> assign(:list_id, list_id)
    |> assign(:form, to_form(%{"name" => "", "details" => ""}))
  end

  defp fetch_board(socket, id) do
    case BoardClient.one(id) do
      {:ok, response} ->
        board = response.body["data"]
        socket =
          socket
          |> assign(:board, board)
          |> assign(:page_title, board["name"])

        socket
      {:error, _} -> push_navigate(socket, to: ~p"/")
    end
  end

  def handle_event("save_list", params, socket) do
    case BoardClient.create_list(socket.assigns.board["id"], params) do
      {:ok, response} ->
        IO.inspect(response)
        case response.status do
          201 -> {:noreply, socket
            |> put_flash(:info, "List successfully created!")
            |> fetch_board(socket.assigns.board["id"])
            |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
          422 -> {:noreply, socket |> put_flash(:error, "Failed in creating new list") |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
          _ -> {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
        end
      {:error, error} ->
        IO.inspect(error)
        {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
    end
  end

  def handle_event("save_task", params, socket) do
    case BoardClient.create_task(socket.assigns.list_id, "afc57835-910d-495f-a0b9-232bb7392adb", params) do
      {:ok, response} ->
        case response.status do
          201 -> {:noreply, socket
            |> put_flash(:info, "Task successfully created!")
            |> fetch_board(socket.assigns.board["id"])
            |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
          422 -> {:noreply, socket |> put_flash(:error, "Failed in creating new task") |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
          _ -> {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
        end
      {:error, error} ->
        IO.inspect(error)
        {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
    end
  end

end
