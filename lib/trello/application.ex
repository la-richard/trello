defmodule Trello.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TrelloWeb.Telemetry,
      Trello.Repo,
      {DNSCluster, query: Application.get_env(:trello, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Trello.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Trello.Finch},
      # Start a worker by calling: Trello.Worker.start_link(arg)
      # {Trello.Worker, arg},
      # Start to serve requests, typically the last entry
      TrelloWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Trello.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TrelloWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
