defmodule TrelloWeb.UserRegistrationLive do
  alias TrelloWeb.UserClient
  use TrelloWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Register for an account
        <:subtitle>
          Already registered?
          <.link navigate={~p"/users/login"} class="font-semibold text-brand hover:underline">
            Sign in
          </.link>
          to your account now.
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="registration_form"
        phx-submit="register"
      >
        <.error :if={@check_errors}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Password" required />

        <:actions>
          <.button phx-disable-with="Creating account..." class="w-full">Create an account</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign(:form, to_form(%{"email" => "", "password" => ""}))

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("register", params, socket) do
    case UserClient.register(params) do
      {:ok, response} ->
        case response.status do
          201 -> {:noreply, socket |> put_flash(:info, "Successfully registered! Please log in with your new user.") |> push_navigate(to: ~p"/login")}
          422 -> {:noreply, socket |> put_flash(:error, "Invalid email / password.")}
          _ -> {:noreply, put_flash(socket, :error, "Something went wrong! Try again later.")}
        end
      {:error, _} ->
        {:noreply, put_flash(socket, :info, "Something went wrong! Try again later.")}
    end
  end

end
