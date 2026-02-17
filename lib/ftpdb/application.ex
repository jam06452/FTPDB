defmodule Ftpdb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FtpdbWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:ftpdb, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Ftpdb.PubSub},
      # Start a worker by calling: Ftpdb.Worker.start_link(arg)
      # {Ftpdb.Worker, arg},
      # Start to serve requests, typically the last entry
      FtpdbWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ftpdb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FtpdbWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
