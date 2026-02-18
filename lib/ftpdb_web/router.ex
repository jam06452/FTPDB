defmodule FtpdbWeb.Router do
  use FtpdbWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FtpdbWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FtpdbWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/project/:id", PageController, :project
    get "/user/:user_id", PageController, :user
    get "/suggestions", PageController, :suggestions
    get "/projects", PageController, :projects
  end

  scope "/api", FtpdbWeb do
    pipe_through :api

    get "/hot", ApiController, :hot
    get "/top_this_week", ApiController, :top_this_week
    get "/fan_favourites", ApiController, :fan_favourites
    get "/top_all_time", ApiController, :top_all_time
    get "/most_time_spent", ApiController, :most_time_spent
    get "/random_projects", ApiController, :random_projects
    get "/devlogs/:id", ApiController, :devlogs
    get "/project_info/:id", ApiController, :project_info
    get "/user_info/:id", ApiController, :user_info
    get "/user_projects/:user_id", ApiController, :user_projects
    get "/search", ApiController, :search

    post "/suggest", ApiController, :suggest
  end

  # Other scopes may use custom stacks.
  # scope "/api", FtpdbWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:ftpdb, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FtpdbWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
