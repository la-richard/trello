defmodule TrelloWeb.BoardLive.Index do
  use TrelloWeb, :live_view

  alias TrelloWeb.BoardClient

  def mount(_params, session, socket) do
    {:ok, assign(socket, :api_client, BoardClient.new(session["access_token"]))}
  end

  def handle_params(%{"board_id" => board_id} = params, _uri, socket) do
    %{api_client: api_client, current_user: %{"id" => user_id}, live_action: live_action} = socket.assigns
    board = fetch_board(api_client, board_id)
    lists = fetch_lists(api_client, board_id)
    tasks = Enum.reduce(lists, %{}, fn %{"id" => id}, acc -> Map.put(acc, id, fetch_tasks(api_client, id)) end)
    permission = get_permission(user_id, board["owner"]["id"], board["users"], board["visibility"])
    board_users = [board["owner"]["id"] | Enum.map(board["users"], fn %{"user_id" => user_id} -> user_id end)]

    if permission do
      socket =
        socket
        |> assign(:board, board)
        |> assign(:board_users, board_users)
        |> assign(:lists, lists)
        |> assign(:tasks, tasks)
        |> assign(:permission, permission)

      if live_action in [:add_member, :create_list, :create_task] && permission == "read" do
        {:noreply, socket |> put_flash(:error, "You don't have access to that.") |> push_patch(to: ~p"/boards/#{board_id}")}
      else
        {:noreply, apply_action(socket, socket.assigns.live_action, params)}
      end
    else
      {:noreply, socket |> put_flash(:error, "You don't have access to that board.") |> push_navigate(to: ~p"/")}
    end
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, socket.assigns.board["name"])
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

  defp apply_action(socket, :add_member, _params) do
    socket
    |> assign(:page_title, "Add member | #{socket.assigns.board["name"]}")
    |> assign(:search_result, [])
    |> assign(:new_member_permission, :read)
  end

  defp fetch_board(client, board_id) do
    case BoardClient.one(client, board_id) do
      {:ok, response} ->
        if response.status == 200, do: response.body["data"], else: []
      {:error, _} -> []
    end
  end

  defp fetch_lists(client, board_id) do
    case BoardClient.board_lists(client, board_id) do
      {:ok, response} ->
        if response.status == 200, do: response.body["data"], else: []
      {:error, _} -> []
    end
  end

  defp fetch_tasks(client, list_id) do
    case BoardClient.list_tasks(client, list_id) do
      {:ok, response} ->
        if response.status == 200, do: response.body["data"], else: []
      {:error, _} -> []
    end
  end

  def handle_event("save_list", params, socket) do
    case BoardClient.create_list(socket.assigns.api_client, socket.assigns.board["id"], params) do
      {:ok, response} ->
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
    %{
      api_client: api_client,
      current_user: %{"id" => user_id},
      list_id: list_id,
      board: %{"id" => board_id}
    } = socket.assigns
    case BoardClient.create_task(api_client, list_id, user_id, params) do
      {:ok, response} ->
        case response.status do
          201 -> {:noreply, socket
            |> put_flash(:info, "Task successfully created!")
            |> push_patch(to: ~p"/boards/#{board_id}")}
          422 -> {:noreply, socket |> put_flash(:error, "Failed in creating new task") |> push_patch(to: ~p"/boards/#{board_id}")}
          _ -> {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{board_id}")}
        end
      {:error, error} ->
        IO.inspect(error)
        {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{board_id}")}
    end
  end

  def handle_event("reorder", params, socket) do
    %{api_client: api_client, board: %{"id" => board_id}} = socket.assigns
    from_list = Map.get(params, "fromList")
    task_id = Map.get(params, "movedId")
    next_sibling_id = Map.get(params, "nextSiblingId")
    previous_sibling_id = Map.get(params, "previousSiblingId")
    to_list = Map.get(params, "toList")

    case reorder_tasks(api_client, from_list, to_list, task_id, previous_sibling_id, next_sibling_id) do
      {:ok, response} ->
        case response.status do
          200 -> {:noreply, socket |> put_flash(:info, "Task successfully reordered!") |> push_patch(to: ~p"/boards/#{board_id}")}
          422 -> {:noreply, socket |> put_flash(:error, "Failed in reordering task") |> push_patch(to: ~p"/boards/#{board_id}")}
          _ -> {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{board_id}")}
        end
      {:error, error} ->
        IO.inspect(error)
        {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{board_id}")}
    end
  end

  def handle_event("user_search", %{"search_query" => search_query}, socket) do
    if String.length(search_query) == 0 do
      {:noreply, assign(socket, :search_result, [])}
    else
      %{api_client: api_client, board_users: board_users} = socket.assigns
      case BoardClient.search_user(api_client, search_query) do
        {:ok, response} ->
          if response.status == 200 do
            board_users_available = Enum.filter(response.body["data"], fn %{"id" => user_id} -> user_id not in board_users end)
            {:noreply, assign(socket, :search_result, board_users_available)}
          else
            {:noreply, assign(socket, :search_result, [])}
          end
        {:error, _} -> {:noreply, assign(socket, :search_result, [])}
      end
    end
  end

  def handle_event("add_board_user", %{"user" => user_id}, socket) do
    %{api_client: api_client, board: %{"id" => board_id}, new_member_permission: new_member_permission} = socket.assigns
    case BoardClient.add_or_update_board_user(api_client, board_id, user_id, new_member_permission) do
      {:ok, response} ->
        if response.status == 201 do
          {:noreply, socket |> put_flash(:info, "User added to board!") |> push_patch(to: ~p"/boards/#{board_id}")}
        else
          {:noreply, socket |> put_flash(:error, "Failed to add user to board!") |> push_patch(to: ~p"/boards/#{board_id}")}
        end
      {:error, _} -> {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{board_id}")}
    end
  end

  def handle_event("set_permission", %{"permission" => permission}, socket) do
    {:noreply, assign(socket, new_member_permission: permission)}
  end

  def handle_event("remove_board_user", %{"user" => user_id}, socket) do
    %{api_client: api_client, board: %{"id" => board_id}} = socket.assigns
    case BoardClient.remove_board_user(api_client, board_id, user_id) do
      {:ok, response} ->
        if response.status == 200 do
          {:noreply, socket |> put_flash(:info, "User removed from board!") |> push_patch(to: ~p"/boards/#{board_id}")}
        else
          {:noreply, socket |> put_flash(:error, "Failed to remove user from board!") |> push_patch(to: ~p"/boards/#{board_id}")}
        end
      {:error, _} -> {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{board_id}")}
    end
  end

  def handle_event("update_permission", %{"user" => user_id, "permission" => permission}, socket) do
    %{api_client: api_client, board: %{"id" => board_id}} = socket.assigns
    case BoardClient.add_or_update_board_user(api_client, board_id, user_id, permission) do
      {:ok, response} ->
        if response.status == 201 do
          {:noreply, socket |> put_flash(:info, "User permission updated!") |> push_patch(to: ~p"/boards/#{board_id}")}
        else
          {:noreply, socket |> put_flash(:error, "Failed to update user permission!") |> push_patch(to: ~p"/boards/#{board_id}")}
        end
      {:error, _} -> {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{board_id}")}
    end
  end

  def handle_event("delete_list", %{"list_id" => list_id}, socket) do
    %{api_client: api_client, board: %{"id" => board_id}} = socket.assigns
    case BoardClient.delete_list(api_client, list_id) do
      {:ok, response} ->
        if response.status == 200 do
          {:noreply, socket |> put_flash(:info, "List removed from board!") |> push_patch(to: ~p"/boards/#{board_id}")}
        else
          {:noreply, socket |> put_flash(:error, "Failed to remove list from board!") |> push_patch(to: ~p"/boards/#{board_id}")}
        end
      {:error, _} -> {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{board_id}")}
    end
  end

  def handle_event("delete_board", _params, socket) do
    %{api_client: api_client, board: %{"id" => board_id}} = socket.assigns
    case BoardClient.delete_board(api_client, board_id) do
      {:ok, response} ->
        if response.status == 200 do
          {:noreply, socket |> put_flash(:info, "Board successfully deleted!") |> push_navigate(to: ~p"/")}
        else
          {:noreply, socket |> put_flash(:error, "Failed to delete board!") |> push_patch(to: ~p"/boards/#{board_id}")}
        end
      {:error, _} -> {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later.") |> push_patch(to: ~p"/boards/#{board_id}")}
    end
  end

  defp reorder_tasks(client, from_list, to_list, task_id, prev_id, next_id) when from_list == to_list do
    BoardClient.reorder_task(client, task_id, %{"prev_id" => prev_id, "next_id" => next_id})
  end

  defp reorder_tasks(client, from_list, to_list, task_id, prev_id, next_id) when from_list != to_list do
    BoardClient.reorder_task(client, task_id, %{"list_id" => to_list, "prev_id" => prev_id, "next_id" => next_id})
  end

  defp get_permission(user_id, owner_id, board_users, board_visibility) do
    if owner_id == user_id do
      "manage"
    else
      board_user = Enum.find(board_users, fn board_user -> board_user["user_id"] == user_id end)
      if board_user do
        board_user["permission"]
      else
        if board_visibility == "public", do: "read", else: nil
      end
    end
  end

end
