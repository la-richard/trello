defmodule TrelloWeb.BoardLive.Index do
  use TrelloWeb, :live_view

  alias TrelloWeb.BoardClient

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, %{"board_id" => board_id}) do
    board = fetch_board(board_id)
    lists = fetch_lists(board_id)
    tasks = Enum.reduce(lists, %{}, fn %{"id" => id}, acc -> Map.put(acc, id, fetch_tasks(id)) end)

    socket
    |> assign(:board, board)
    |> assign(:page_title, board["name"])
    |> assign(:lists, lists)
    |> assign(:tasks, tasks)
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

  defp fetch_board(board_id) do
    case BoardClient.one(board_id) do
      {:ok, response} ->
        if response.status == 200, do: response.body["data"], else: []
      {:error, _} -> []
    end
  end

  defp fetch_lists(board_id) do
    case BoardClient.board_lists(board_id) do
      {:ok, response} ->
        if response.status == 200, do: response.body["data"], else: []
      {:error, _} -> []
    end
  end

  defp fetch_tasks(list_id) do
    case BoardClient.list_tasks(list_id) do
      {:ok, response} ->
        if response.status == 200, do: response.body["data"], else: []
      {:error, _} -> []
    end
  end

  def handle_event("save_list", params, socket) do
    case BoardClient.create_list(socket.assigns.board["id"], params) do
      {:ok, response} ->
        IO.inspect(response)
        case response.status do
          201 -> {:noreply, socket
            |> put_flash(:info, "List successfully created!")
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
    case BoardClient.create_task(socket.assigns.list_id, "b093bd77-084a-499f-a77b-845eca0a718b", params) do
      {:ok, response} ->
        case response.status do
          201 -> {:noreply, socket
            |> put_flash(:info, "Task successfully created!")
            |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
          422 -> {:noreply, socket |> put_flash(:error, "Failed in creating new task") |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
          _ -> {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
        end
      {:error, error} ->
        IO.inspect(error)
        {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
    end
  end

  def handle_event("reorder", params, socket) do
    from_list = Map.get(params, "fromList")
    task_id = Map.get(params, "movedId")
    next_sibling_id = Map.get(params, "nextSiblingId")
    previous_sibling_id = Map.get(params, "previousSiblingId")
    to_list = Map.get(params, "toList")
    case reorder_tasks(from_list, to_list, task_id, previous_sibling_id, next_sibling_id) do
      {:ok, response} ->
        case response.status do
          200 -> {:noreply, socket |> put_flash(:info, "Task successfully reordered!") |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
          422 -> {:noreply, socket |> put_flash(:error, "Failed in reordering task") |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
          _ -> {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
        end
      {:error, error} ->
        IO.inspect(error)
        {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{socket.assigns.board["id"]}")}
    end
  end

  defp reorder_tasks(from_list, to_list, task_id, prev_id, next_id) when from_list == to_list do
    BoardClient.reorder_task(task_id, %{"prev_id" => prev_id, "next_id" => next_id})
  end

  defp reorder_tasks(from_list, to_list, task_id, prev_id, next_id) when from_list != to_list do
    BoardClient.reorder_task(task_id, %{"list_id" => to_list, "prev_id" => prev_id, "next_id" => next_id})
  end

end
