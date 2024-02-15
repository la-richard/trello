defmodule TrelloWeb.BoardLive.Index do
  use TrelloWeb, :live_view

  def handle_params(%{"id" => id}, _uri, socket) do
    socket =
      socket
      |> assign(:board, id)
      |> assign(:page_title, id)

    {:noreply, assign(socket, :board, id)}
  end

end
