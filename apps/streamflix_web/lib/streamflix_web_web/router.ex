defmodule StreamflixWebWeb.Router do
  use StreamflixWebWeb, :router

  def api_spec, do: StreamflixWebWeb.ApiSpec.spec()

  defp assign_current_path(conn, _opts) do
    Plug.Conn.assign(conn, :current_path, conn.request_path)
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug StreamflixWebWeb.Plugs.SetLocale
    plug StreamflixWebWeb.Plugs.MaybeLoadCurrentUser
    plug StreamflixWebWeb.Plugs.SessionTimeout
    plug :put_root_layout, html: {StreamflixWebWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :assign_current_path
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug StreamflixWebWeb.Plugs.ApiVersion
  end

  pipeline :api_auth_rate_limit do
    plug StreamflixWebWeb.Plugs.RateLimit,
      path_rules: [
        {"POST", "/api/v1/auth/login", 15},
        {"POST", "/api/v1/auth/register", 5},
        {"POST", "/api/v1/auth/refresh", 30},
        {"POST", "/api/v1/auth/mfa/verify", 10}
      ],
      window_sec: 60

    plug StreamflixWebWeb.Plugs.ValidateAuthParams
  end

  pipeline :browser_auth_rate_limit do
    plug StreamflixWebWeb.Plugs.RateLimit,
      path_rules: [
        {"POST", "/login", 5},
        {"POST", "/signup", 3},
        {"POST", "/mfa/verify", 10},
        {"POST", "/mfa/verify-backup", 5}
      ],
      window_sec: 60
  end

  pipeline :api_auth do
    plug StreamflixWebWeb.Plugs.Auth
  end

  pipeline :api_key_auth do
    plug StreamflixWebWeb.Plugs.ApiKeyAuth
    plug StreamflixWebWeb.Plugs.ProjectRateLimit
  end

  pipeline :openapi do
    plug OpenApiSpex.Plug.PutApiSpec, module: StreamflixWebWeb.ApiSpec
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

  # Health check para load balancers y monitoring
  scope "/", StreamflixWebWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end

  # Public status page
  scope "/", StreamflixWebWeb do
    pipe_through :browser

    live_session :public,
      on_mount: [
        {StreamflixWebWeb.LiveLocale, :set},
        {StreamflixWebWeb.LiveAuth, :mount_current_user_optional}
      ] do
      live "/status", StatusLive, :index
      live "/docs", DocsLive, :index
    end
  end

  # OpenAPI spec + Swagger UI (dev/test only — not exposed in production)
  if Application.compile_env(:streamflix_web, :dev_routes) do
    scope "/api" do
      pipe_through [:api, :openapi]

      get "/openapi", OpenApiSpex.Plug.RenderSpec, []
    end

    scope "/api" do
      pipe_through [:browser, :openapi]

      get "/swaggerui", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi"
    end
  end

  # Sandbox catch-all (receives webhook test requests)
  scope "/sandbox", StreamflixWebWeb do
    pipe_through :api

    match :*, "/:slug", SandboxController, :receive
    match :*, "/:slug/*path", SandboxController, :receive
  end

  # Sitemap para SEO (Google Search Console)
  scope "/", StreamflixWebWeb do
    pipe_through :browser

    get "/sitemap.xml", SitemapController, :index
  end

  # Auth routes + public docs + términos/privacidad (accesibles siempre, con o sin login)
  scope "/", StreamflixWebWeb do
    pipe_through [:browser, :browser_auth_rate_limit]

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
    get "/mfa/verify", MfaController, :show
    post "/mfa/verify", MfaController, :verify
    post "/mfa/verify-backup", MfaController, :verify_backup
    delete "/logout", AuthController, :logout
    get "/logout", AuthController, :logout
    get "/forgot-password", PageController, :forgot_password
    post "/forgot-password", AuthController, :forgot_password
    get "/reset-password/:token", PageController, :reset_password
    post "/reset-password/:token", AuthController, :reset_password
    get "/confirm-email/:token", AuthController, :confirm_email
  end

  # ============================================
  # API V1 - PUBLIC
  # ============================================

  scope "/api/v1", StreamflixWebWeb.Api.V1, as: :api_v1 do
    pipe_through [:api, :api_auth_rate_limit]

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
    post "/auth/mfa/verify", AuthController, :verify_mfa
  end

  # ============================================
  # API V1 - PLATFORM (Webhooks + Events) - API Key auth
  # ============================================

  scope "/api/v1", StreamflixWebWeb.Api.V1, as: :api_v1 do
    pipe_through [:api, :api_key_auth]

    post "/send", PlatformEventsController, :create
    post "/events", PlatformEventsController, :create
    post "/events/batch", PlatformEventsController, :batch
    get "/events", PlatformEventsController, :index
    get "/events/:id", PlatformEventsController, :show
    delete "/events/:id", PlatformEventsController, :delete

    post "/simulate", PlatformEventsController, :simulate

    get "/webhooks/templates", PlatformWebhooksController, :templates
    get "/webhooks", PlatformWebhooksController, :index
    post "/webhooks", PlatformWebhooksController, :create
    get "/webhooks/:id", PlatformWebhooksController, :show
    get "/webhooks/:id/health", PlatformWebhooksController, :health
    patch "/webhooks/:id", PlatformWebhooksController, :update
    delete "/webhooks/:id", PlatformWebhooksController, :delete

    get "/deliveries", PlatformDeliveriesController, :index
    post "/deliveries/:id/retry", PlatformDeliveriesController, :retry

    get "/dead-letters", PlatformDeadLettersController, :index
    get "/dead-letters/:id", PlatformDeadLettersController, :show
    post "/dead-letters/:id/retry", PlatformDeadLettersController, :retry
    patch "/dead-letters/:id/resolve", PlatformDeadLettersController, :resolve

    post "/replays", PlatformReplaysController, :create
    get "/replays", PlatformReplaysController, :index
    get "/replays/:id", PlatformReplaysController, :show
    delete "/replays/:id", PlatformReplaysController, :cancel

    # Pipelines
    get "/pipelines", PipelineController, :index
    post "/pipelines", PipelineController, :create
    get "/pipelines/:id", PipelineController, :show
    patch "/pipelines/:id", PipelineController, :update
    delete "/pipelines/:id", PipelineController, :delete
    post "/pipelines/:id/test", PipelineController, :test

    get "/audit-log", PlatformAuditController, :index

    get "/sandbox-endpoints", PlatformSandboxController, :index
    post "/sandbox-endpoints", PlatformSandboxController, :create
    delete "/sandbox-endpoints/:id", PlatformSandboxController, :delete
    get "/sandbox-endpoints/:id/requests", PlatformSandboxController, :requests

    get "/analytics/events-per-day", PlatformAnalyticsController, :events_per_day
    get "/analytics/deliveries-per-day", PlatformAnalyticsController, :deliveries_per_day
    get "/analytics/top-topics", PlatformAnalyticsController, :top_topics
    get "/analytics/webhook-stats", PlatformAnalyticsController, :webhook_stats

    get "/jobs", PlatformJobsController, :index
    post "/jobs", PlatformJobsController, :create
    get "/jobs/cron-preview", PlatformJobsController, :cron_preview
    get "/jobs/:id", PlatformJobsController, :show
    patch "/jobs/:id", PlatformJobsController, :update
    delete "/jobs/:id", PlatformJobsController, :delete
    get "/jobs/:id/runs", PlatformJobsController, :runs

    get "/project", PlatformProjectController, :show
    patch "/project", PlatformProjectController, :update
    get "/topics", PlatformProjectController, :topics
    get "/token", PlatformProjectController, :token
    post "/token/regenerate", PlatformProjectController, :regenerate_token

    # Event Schemas (B14)
    get "/event-schemas", PlatformEventSchemasController, :index
    post "/event-schemas", PlatformEventSchemasController, :create
    get "/event-schemas/:id", PlatformEventSchemasController, :show
    patch "/event-schemas/:id", PlatformEventSchemasController, :update
    delete "/event-schemas/:id", PlatformEventSchemasController, :delete
    post "/event-schemas/validate", PlatformEventSchemasController, :validate

    # SSE Stream (B17)
    get "/stream", PlatformSSEController, :stream

    # Export (B16)
    get "/export/events", PlatformExportController, :events
    get "/export/deliveries", PlatformExportController, :deliveries
    get "/export/jobs", PlatformExportController, :jobs
    get "/export/audit-log", PlatformExportController, :audit_log
  end

  # ============================================
  # API V1 - JWT auth routes (Projects, Teams)
  # ============================================

  scope "/api/v1", StreamflixWebWeb.Api.V1, as: :api_v1 do
    pipe_through [:api, :api_auth]

    # Multi-project (B11)
    get "/projects", PlatformProjectsController, :index
    post "/projects", PlatformProjectsController, :create
    get "/projects/:id", PlatformProjectsController, :show
    patch "/projects/:id", PlatformProjectsController, :update
    delete "/projects/:id", PlatformProjectsController, :delete
    patch "/projects/:id/default", PlatformProjectsController, :set_default

    # Team Members (B20)
    get "/projects/:project_id/members", PlatformMembersController, :index
    post "/projects/:project_id/members", PlatformMembersController, :create
    patch "/projects/:project_id/members/:id", PlatformMembersController, :update
    delete "/projects/:project_id/members/:id", PlatformMembersController, :delete

    # Invitations
    get "/invitations/pending", PlatformMembersController, :pending
    post "/invitations/:id/accept", PlatformMembersController, :accept
    post "/invitations/:id/reject", PlatformMembersController, :reject

    # GDPR — Consent management
    get "/me/consents", GDPRController, :consent_status
    post "/me/consents/:purpose/accept", GDPRController, :accept_consent

    # GDPR — Data export (DSAR)
    get "/me/data", GDPRController, :export_my_data

    # GDPR — Restriction (Art. 18)
    post "/me/restrict", GDPRController, :restrict
    delete "/me/restrict", GDPRController, :lift_restriction

    # GDPR — Objection (Art. 21)
    post "/me/object", GDPRController, :object
    delete "/me/object", GDPRController, :restore_consent
  end

  # ============================================
  # LIVE VIEWS - AUTHENTICATED (solo plataforma Webhooks + Events)
  # ============================================

  scope "/", StreamflixWebWeb do
    pipe_through [:browser]

    live_session :default,
      on_mount: [
        {StreamflixWebWeb.LiveLocale, :set},
        {StreamflixWebWeb.LiveAuth, :mount_current_user}
      ] do
      live "/account", AccountLive, :index
      live "/platform", PlatformDashboardLive, :index
    end
  end

  # Browser-initiated export downloads (session-based auth)
  scope "/", StreamflixWebWeb do
    pipe_through [:browser]

    get "/export/events", BrowserExportController, :events
    get "/export/deliveries", BrowserExportController, :deliveries
    get "/export/jobs", BrowserExportController, :jobs
    get "/export/audit-log", BrowserExportController, :audit_log
    get "/export/my-data", BrowserExportController, :my_data
  end

  # ============================================
  # ADMIN PANEL (Superadmin)
  # ============================================

  scope "/admin", StreamflixWebWeb.Admin do
    pipe_through [:browser]

    live_session :admin,
      on_mount: [
        {StreamflixWebWeb.LiveLocale, :set},
        {StreamflixWebWeb.LiveAuth, :mount_admin_user}
      ] do
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
