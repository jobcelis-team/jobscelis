defmodule StreamflixWebWeb.Router do
  use StreamflixWebWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {StreamflixWebWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug StreamflixWebWeb.Plugs.Auth
  end

  # ============================================
  # PUBLIC ROUTES
  # ============================================

  scope "/", StreamflixWebWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/login", PageController, :login
    post "/login", AuthController, :login
    get "/signup", PageController, :signup
    post "/signup", AuthController, :register
    delete "/logout", AuthController, :logout
  end

  # ============================================
  # API V1 - PUBLIC
  # ============================================

  scope "/api/v1", StreamflixWebWeb.Api.V1, as: :api_v1 do
    pipe_through :api

    # Auth endpoints
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
  end

  # ============================================
  # API V1 - AUTHENTICATED
  # ============================================

  scope "/api/v1", StreamflixWebWeb.Api.V1, as: :api_v1 do
    pipe_through [:api, :api_auth]

    # Catalog (implemented)
    get "/browse", CatalogController, :browse
    get "/browse/genre/:genre", CatalogController, :by_genre
    get "/content/:id", CatalogController, :show
    get "/content/:id/seasons", CatalogController, :seasons
    get "/content/:id/seasons/:season/episodes", CatalogController, :episodes

    # Playback
    post "/playback/start", PlaybackController, :start
    put "/playback/:session_id/heartbeat", PlaybackController, :heartbeat
    delete "/playback/:session_id", PlaybackController, :stop
    get "/playback/:session_id/manifest", PlaybackController, :manifest

    # User
    get "/me", UserController, :me
    put "/me", UserController, :update

    # Profiles
    resources "/profiles", ProfileController, only: [:index, :show, :create, :update, :delete]

    # Search
    get "/search", SearchController, :search
    get "/search/autocomplete", SearchController, :autocomplete

    # Streaming
    get "/stream/:session_id/:quality/playlist.m3u8", StreamController, :media_playlist
    get "/stream/:session_id/:quality/segments/:segment", StreamController, :segment

    # My List
    get "/my-list", MyListController, :index
    post "/my-list/:content_id", MyListController, :add
    delete "/my-list/:content_id", MyListController, :remove

    # Ratings
    post "/content/:content_id/rate", RatingController, :rate
    delete "/content/:content_id/rate", RatingController, :unrate

    # History
    get "/history", HistoryController, :index
    get "/continue-watching", HistoryController, :continue_watching
  end

  # ============================================
  # LIVE VIEWS - AUTHENTICATED
  # ============================================

  scope "/", StreamflixWebWeb do
    pipe_through [:browser]

    live_session :default, on_mount: [{StreamflixWebWeb.LiveAuth, :mount_current_user}] do
      live "/browse", BrowseLive, :index
      live "/search", SearchLive, :index
      live "/title/:id", TitleLive, :show
      live "/watch/:id", PlayerLive, :show
      live "/my-list", MyListLive, :index
      live "/profiles", ProfilesLive, :index
      live "/account", AccountLive, :index
    end
  end

  # ============================================
  # ADMIN PANEL
  # ============================================

  scope "/admin", StreamflixWebWeb.Admin do
    pipe_through [:browser]

    live_session :admin do
      live "/", DashboardLive, :index
      live "/content", ContentLive, :index
      live "/content/new", ContentLive, :new
      live "/content/:id/edit", ContentLive, :edit
      live "/users", UsersLive, :index
      live "/analytics", AnalyticsLive, :index
      live "/settings", SettingsLive, :index
    end
  end

  # ============================================
  # DEV ROUTES
  # ============================================

  if Application.compile_env(:streamflix_web, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: StreamflixWebWeb.Telemetry
    end
  end
end
