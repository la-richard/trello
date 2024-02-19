defmodule TrelloWeb.Router do
  use TrelloWeb, :router

  import TrelloWeb.Auth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TrelloWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TrelloWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated, on_mount: [{TrelloWeb.Auth, :redirect_if_user_is_authenticated}] do
      live "/login", UserLoginLive, :new
      live "/register", UserRegistrationLive, :new
    end

    post "/users/login", SessionController, :login
  end

  scope "/", TrelloWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user, on_mount: [{TrelloWeb.Auth, :ensure_authenticated}] do
      live "/", DashboardLive.Index, :index
      live "/boards/create", DashboardLive.Index, :create

      live "/boards/:board_id", BoardLive.Index, :index
      live "/boards/:board_id/members", BoardLive.Index, :add_member
      live "/boards/:board_id/lists", BoardLive.Index, :create_list
      live "/boards/:board_id/lists/:list_id", BoardLive.Index, :create_task

      live "/tasks/:task_id", TaskLive.Show, :show
      live "/tasks/:task_id/edit", TaskLive.Show, :edit
    end

    delete "/users/logout", SessionController, :logout
  end

  # Other scopes may use custom stacks.
  # scope "/api", TrelloWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:trello, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TrelloWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
