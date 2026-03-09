defmodule Ftpdb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Supervisor.child_spec({Cachex, name: :project_cache}, id: :project_cache_worker),
      Supervisor.child_spec({Cachex, name: :user_cache}, id: :user_cache_worker),
      Supervisor.child_spec({Cachex, name: :devlog_cache}, id: :devlog_cache_worker),
      Supervisor.child_spec({Cachex, name: :random_devlog_cache},
        id: :random_devlog_cache_worker
      ),
      Supervisor.child_spec({Cachex, name: :random_project_cache},
        id: :random_project_cache_worker
      ),
      Supervisor.child_spec({Cachex, name: :user_id_cache}, id: :user_id_cache_worker),
      Supervisor.child_spec({Cachex, name: :hot_cache}, id: :hot_cache_worker),
      Supervisor.child_spec({Cachex, name: :top_week_cache}, id: :top_week_cache_worker),
      Supervisor.child_spec({Cachex, name: :top_all_time_cache}, id: :top_all_time_cache_worker),
      Supervisor.child_spec({Cachex, name: :most_time_spent_cache},
        id: :most_time_spent_cache_worker
      ),
      Supervisor.child_spec({Cachex, name: :fan_favourites_cache},
        id: :fan_favourites_cache_worker
      ),
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

    case Supervisor.start_link(children, opts) do
      {:ok, _pid} = result ->
        maybe_warm_random_caches()
        result

      other ->
        other
    end
  end

  defp maybe_warm_random_caches do
    if Application.get_env(:ftpdb, :warm_random_cache_on_start, true) do
      Task.start(fn -> Ftpdb.DB.warm_random_caches() end)
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FtpdbWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
