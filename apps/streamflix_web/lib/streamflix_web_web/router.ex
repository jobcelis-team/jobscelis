defmodule StreamflixWebWeb.Router do
  use StreamflixWebWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug StreamflixWebWeb.Plugs.SetLocale
    plug :put_root_layout, html: {StreamflixWebWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth_rate_limit do
    plug StreamflixWebWeb.Plugs.RateLimit,
      path_rules: [
        {"POST", "/api/v1/auth/login", 15},
        {"POST", "/api/v1/auth/register", 5},
        {"POST", "/api/v1/auth/refresh", 30}
      ],
      window_sec: 60
    plug StreamflixWebWeb.Plugs.ValidateAuthParams
  end

  pipeline :browser_auth_rate_limit do
    plug StreamflixWebWeb.Plugs.RateLimit,
      path_rules: [
        {"POST", "/login", 5},
        {"POST", "/signup", 3}
      ],
      window_sec: 60
  end

  pipeline :api_auth do
    plug StreamflixWebWeb.Plugs.Auth
  end

  pipeline :api_key_auth do
    plug StreamflixWebWeb.Plugs.ApiKeyAuth
  end

  # ============================================
  # PUBLIC ROUTES (redirect if authenticated)
  # ============================================

  scope "/", StreamflixWebWeb do
    pipe_through [:browser, StreamflixWebWeb.Plugs.RedirectIfAuthenticated]

    get "/", PageController, :home
    get "/login", PageController, :login
    get "/signup", PageController, :signup
  end

  # Cambio de idioma (guarda en sesión y redirige)
  scope "/", StreamflixWebWeb do
    pipe_through :browser

    get "/locale/:locale", PageController, :set_locale
  end

  # Auth routes + public docs + términos/privacidad (accesibles siempre, con o sin login)
  scope "/", StreamflixWebWeb do
    pipe_through [:browser, :browser_auth_rate_limit]

    get "/docs", PageController, :docs
    get "/faq", PageController, :faq
    get "/about", PageController, :about
    get "/contact", PageController, :contact
    get "/pricing", PageController, :pricing
    get "/terms", PageController, :terms
    get "/privacy", PageController, :privacy
    get "/cookies", PageController, :cookies
    get "/changelog", PageController, :changelog
    post "/login", AuthController, :login
    post "/signup", AuthController, :register
    delete "/logout", AuthController, :logout
    get "/logout", AuthController, :logout
  end

  # ============================================
  # API V1 - PUBLIC
  # ============================================

  scope "/api/v1", StreamflixWebWeb.Api.V1, as: :api_v1 do
    pipe_through [:api, :api_auth_rate_limit]

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
  end

  # ============================================
  # API V1 - PLATFORM (Webhooks + Events) - API Key auth
  # ============================================

  scope "/api/v1", StreamflixWebWeb.Api.V1, as: :api_v1 do
    pipe_through [:api, :api_key_auth]

    post "/send", PlatformEventsController, :create
    post "/events", PlatformEventsController, :create
    get "/events", PlatformEventsController, :index
    get "/events/:id", PlatformEventsController, :show
    delete "/events/:id", PlatformEventsController, :delete

    get "/webhooks", PlatformWebhooksController, :index
    post "/webhooks", PlatformWebhooksController, :create
    get "/webhooks/:id", PlatformWebhooksController, :show
    patch "/webhooks/:id", PlatformWebhooksController, :update
    delete "/webhooks/:id", PlatformWebhooksController, :delete

    get "/deliveries", PlatformDeliveriesController, :index
    post "/deliveries/:id/retry", PlatformDeliveriesController, :retry

    get "/jobs", PlatformJobsController, :index
    post "/jobs", PlatformJobsController, :create
    get "/jobs/:id", PlatformJobsController, :show
    patch "/jobs/:id", PlatformJobsController, :update
    delete "/jobs/:id", PlatformJobsController, :delete
    get "/jobs/:id/runs", PlatformJobsController, :runs

    get "/project", PlatformProjectController, :show
    patch "/project", PlatformProjectController, :update
    get "/topics", PlatformProjectController, :topics
    get "/token", PlatformProjectController, :token
    post "/token/regenerate", PlatformProjectController, :regenerate_token
  end

  # ============================================
  # LIVE VIEWS - AUTHENTICATED (solo plataforma Webhooks + Events)
  # ============================================

  scope "/", StreamflixWebWeb do
    pipe_through [:browser]

    live_session :default, on_mount: [{StreamflixWebWeb.LiveLocale, :set}, {StreamflixWebWeb.LiveAuth, :mount_current_user}] do
      live "/account", AccountLive, :index
      live "/platform", PlatformDashboardLive, :index
    end
  end

  # ============================================
  # ADMIN PANEL (Superadmin)
  # ============================================

  scope "/admin", StreamflixWebWeb.Admin do
    pipe_through [:browser]

    live_session :admin, on_mount: [{StreamflixWebWeb.LiveLocale, :set}, {StreamflixWebWeb.LiveAuth, :mount_admin_user}] do
      live "/", DashboardLive, :index
      live "/users", UsersLive, :index
      live "/projects", ProjectsLive, :index
      live "/projects/:id", ProjectsLive, :show
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
