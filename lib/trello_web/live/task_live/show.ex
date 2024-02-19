defmodule TrelloWeb.TaskLive.Show do
  alias TrelloWeb.BoardClient
  use TrelloWeb, :live_view

  def mount(_params, session, socket) do
    {:ok, assign(socket, :api_client, BoardClient.new(session["access_token"]))}
  end

  def handle_params(%{"task_id" => task_id} = params, _uri, socket) do
    %{api_client: api_client, current_user: %{"id" => user_id}} = socket.assigns
    task = fetch_task(api_client, task_id)
    board_id = task["list"]["board_id"]
    board = fetch_board(api_client, board_id)
    permission = get_permission(user_id, board["owner"]["id"], board["users"], board["visibility"])

    socket =
      socket
      |> assign(:task, task)
      |> assign(:page_title, task["name"])
      |> assign(:task_form, to_form(%{"name" => task["name"], "details" => task["details"]}))
      |> assign(:permission, permission)
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, %{"task_id" => task_id}) do
    comments = fetch_comments(socket.assigns.api_client, task_id)

    socket
    |> assign(:comments, comments)
    |> assign(:comment_form, to_form(%{"body" => ""}))
  end

  defp apply_action(socket, :edit, _params) do
    if socket.assigns.permission in ["write", "manage"] do
      socket
        |> assign(:page_title, "Edit Task")
    else
      socket
        |> put_flash(:error, "You don't have access to that.")
        |> push_patch(to: ~p"/tasks/#{socket.assigns.task["id"]}")
    end
  end

  defp fetch_task(client, task_id) do
    case BoardClient.task(client, task_id) do
      {:ok, response} ->
        if response.status == 200, do: response.body["data"], else: []
      {:error, _} -> %{}
    end
  end

  defp fetch_comments(client, task_id) do
    case BoardClient.task_comments(client, task_id) do
      {:ok, response} ->
        if response.status == 200, do: response.body["data"], else: []
      {:error, _} -> %{}
    end
  end

  def handle_event("save_comment", params, socket) do
    %{
      api_client: api_client,
      current_user: %{"id" => user_id},
      task: %{"id" => task_id}
    } = socket.assigns

    case BoardClient.create_comment(api_client, task_id, user_id, params) do
      {:ok, response} ->
        if response.status == 201 do
          {:noreply, socket |> put_flash(:info, "Comment successfully posted!") |> push_patch(to: ~p"/tasks/#{task_id}")}
        else
          {:noreply, socket |> put_flash(:error, "Failed to post comment!") |> push_patch(to: ~p"/tasks/#{task_id}")}
        end
      {:error, _} -> {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later") |> push_patch(to: ~p"/tasks/#{task_id}")}
    end
  end

  def handle_event("save_task", params, socket) do
    %{api_client: api_client, task: %{"id" => task_id}} = socket.assigns
    case BoardClient.update_task(api_client, task_id, params) do
      {:ok, response} ->
        if response.status == 200 do
          {:noreply, socket |> put_flash(:info, "Task successfully updated!") |> push_patch(to: ~p"/tasks/#{task_id}")}
        else
          {:noreply, socket |> put_flash(:error, "Failed to update task!") |> push_patch(to: ~p"/tasks/#{task_id}/edit")}
        end
      {:error, _} -> {:noreply, socket |> put_flash(:error, "Failed to update task!") |> push_patch(to: ~p"/tasks/#{task_id}/edit")}
    end
  end

  def handle_event("delete_task", _params, socket) do
    %{api_client: api_client, task: %{"id" => task_id, "list" => %{"board_id" => board_id}}} = socket.assigns
    case BoardClient.delete_task(api_client, task_id) do
      {:ok, response} ->
        if response.status == 200 do
          {:noreply, socket |> put_flash(:info, "Task successfully deleted!") |> push_navigate(to: ~p"/boards/#{board_id}")}
        else
          {:noreply, socket |> put_flash(:error, "Failed to delete task!") |> push_patch(to: ~p"/tasks/#{task_id}")}
        end
      {:error, _} -> {:noreply, socket |> put_flash(:error, "Failed to update task!") |> push_patch(to: ~p"/tasks/#{task_id}")}
    end
  end

  defp fetch_board(client, board_id) do
    case BoardClient.one(client, board_id) do
      {:ok, response} ->
        if response.status == 200, do: response.body["data"], else: []
      {:error, _} -> []
    end
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
