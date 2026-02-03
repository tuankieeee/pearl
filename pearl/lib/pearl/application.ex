defmodule Pearl.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PearlWeb.Telemetry,
      Pearl.Repo,
      {DNSCluster, query: Application.get_env(:pearl, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Pearl.PubSub},
      # Start a worker by calling: Pearl.Worker.start_link(arg)
      # {Pearl.Worker, arg},
      # Start to serve requests, typically the last entry
      PearlWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pearl.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PearlWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
