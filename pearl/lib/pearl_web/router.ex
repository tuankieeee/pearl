defmodule PearlWeb.Router do
  use PearlWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PearlWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug PearlWeb.Plugs.Theme
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PearlWeb do
    pipe_through :browser

    post "/theme", ThemeController, :update

    live "/", HomeLive, :index
    live "/wiki/:id", WikiLive, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", PearlWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:pearl, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PearlWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
