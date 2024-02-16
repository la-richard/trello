defmodule TrelloWeb.TaskLive.Show do
  alias TrelloWeb.BoardClient
  use TrelloWeb, :live_view

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, %{"task_id" => task_id}) do
    task = fetch_task(task_id)
    comments = fetch_comments(task_id)

    socket
    |> assign(:task, task)
    |> assign(:page_title, task["name"])
    |> assign(:comments, comments)
    |> assign(:form, to_form(%{"body" => ""}))
  end

  defp fetch_task(task_id) do
    case BoardClient.task(task_id) do
      {:ok, response} ->
        if response.status == 200, do: response.body["data"], else: []
      {:error, _} -> %{}
    end
  end

  defp fetch_comments(task_id) do
    case BoardClient.task_comments(task_id) do
      {:ok, response} ->
        if response.status == 200, do: response.body["data"], else: []
      {:error, _} -> %{}
    end
  end

  def handle_event("save_comment", params, socket) do
    case BoardClient.create_comment(socket.assigns.task["id"], "b093bd77-084a-499f-a77b-845eca0a718b", params) do
      {:ok, response} ->
        if response.status == 201 do
          {:noreply, socket |> put_flash(:info, "Comment successfully posted!") |> push_patch(to: ~p"/tasks/#{socket.assigns.task["id"]}")}
        else
          {:noreply, socket |> put_flash(:error, "Failed to post comment!") |> push_patch(to: ~p"/tasks/#{socket.assigns.task["id"]}")}
        end
      {:error, _} -> {:noreply, socket |> put_flash(:error, "Something went wrong! Try again later") |> push_patch(to: ~p"/tasks/#{socket.assigns.task["id"]}")}
    end
  end

end
