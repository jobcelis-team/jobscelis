# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Jobcelis
  # Client for the Jobcelis Event Infrastructure Platform API.
  #
  # All API calls go to https://jobcelis.com by default.
  #
  #   client = Jobcelis::Client.new(api_key: "your_api_key")
  #
  class Client
    # @param api_key  [String]  Your project API key.
    # @param base_url [String]  Base URL of the Jobcelis API (default: https://jobcelis.com).
    # @param timeout  [Integer] Request timeout in seconds (default: 30).
    def initialize(api_key:, base_url: "https://jobcelis.com", timeout: 30)
      @api_key  = api_key
      @base_url = base_url.chomp("/")
      @timeout  = timeout
      @auth_token = nil
    end

    # ------------------------------------------------------------------
    # Auth
    # ------------------------------------------------------------------

    # Register a new account. Does not use API key auth.
    def register(email:, password:, name: nil)
      body = { email: email, password: password }
      body[:name] = name unless name.nil?
      public_post("/api/v1/auth/register", body)
    end

    # Log in and receive JWT + refresh token. Does not use API key auth.
    def login(email:, password:)
      public_post("/api/v1/auth/login", { email: email, password: password })
    end

    # Refresh an expired JWT using a refresh token. Does not use API key auth.
    def refresh_token(refresh_token)
      public_post("/api/v1/auth/refresh", { refresh_token: refresh_token })
    end

    # Verify MFA code. Requires Bearer token set via set_auth_token.
    def verify_mfa(token:, code:)
      post("/api/v1/auth/mfa/verify", { token: token, code: code })
    end

    # Set JWT bearer token for authenticated requests.
    def set_auth_token(token)
      @auth_token = token
    end

    # ------------------------------------------------------------------
    # Events
    # ------------------------------------------------------------------

    # Send a single event.
    def send_event(topic, payload, **kwargs)
      post("/api/v1/events", { topic: topic, payload: payload, **kwargs })
    end

    # Send up to 1000 events in a batch.
    def send_events(events)
      post("/api/v1/events/batch", { events: events })
    end

    # Get event details.
    def get_event(event_id)
      get("/api/v1/events/#{event_id}")
    end

    # List events with cursor pagination.
    def list_events(limit: 50, cursor: nil)
      get("/api/v1/events", { limit: limit, cursor: cursor })
    end

    # Deactivate an event.
    def delete_event(event_id)
      do_delete("/api/v1/events/#{event_id}")
    end

    # ------------------------------------------------------------------
    # Simulate
    # ------------------------------------------------------------------

    # Simulate sending an event (dry run).
    def simulate_event(topic, payload)
      post("/api/v1/simulate", { topic: topic, payload: payload })
    end

    # ------------------------------------------------------------------
    # Webhooks
    # ------------------------------------------------------------------

    # Create a webhook.
    def create_webhook(url:, rate_limit: nil, **kwargs)
      body = { url: url, **kwargs }
      body[:rate_limit] = rate_limit if rate_limit
      post("/api/v1/webhooks", body)
    end

    # Get webhook details.
    def get_webhook(webhook_id)
      get("/api/v1/webhooks/#{webhook_id}")
    end

    # List webhooks.
    def list_webhooks(limit: 50, cursor: nil)
      get("/api/v1/webhooks", { limit: limit, cursor: cursor })
    end

    # Update a webhook.
    def update_webhook(webhook_id, rate_limit: nil, **kwargs)
      body = { **kwargs }
      body[:rate_limit] = rate_limit if rate_limit
      patch("/api/v1/webhooks/#{webhook_id}", body)
    end

    # Deactivate a webhook.
    def delete_webhook(webhook_id)
      do_delete("/api/v1/webhooks/#{webhook_id}")
    end

    # Get health status for a webhook.
    def webhook_health(webhook_id)
      get("/api/v1/webhooks/#{webhook_id}/health")
    end

    # List available webhook templates.
    def webhook_templates
      get("/api/v1/webhooks/templates")
    end

    # Send a test delivery to a webhook.
    def test_webhook(webhook_id)
      post("/api/v1/webhooks/#{webhook_id}/test", {})
    end

    # ------------------------------------------------------------------
    # Deliveries
    # ------------------------------------------------------------------

    # List deliveries.
    def list_deliveries(limit: 50, cursor: nil, **filters)
      get("/api/v1/deliveries", { limit: limit, cursor: cursor, **filters })
    end

    # Retry a failed delivery.
    def retry_delivery(delivery_id)
      post("/api/v1/deliveries/#{delivery_id}/retry", {})
    end

    # ------------------------------------------------------------------
    # Dead Letters
    # ------------------------------------------------------------------

    # List dead letters.
    def list_dead_letters(limit: 50, cursor: nil)
      get("/api/v1/dead-letters", { limit: limit, cursor: cursor })
    end

    # Get dead letter details.
    def get_dead_letter(dead_letter_id)
      get("/api/v1/dead-letters/#{dead_letter_id}")
    end

    # Retry a dead letter.
    def retry_dead_letter(dead_letter_id)
      post("/api/v1/dead-letters/#{dead_letter_id}/retry", {})
    end

    # Mark a dead letter as resolved.
    def resolve_dead_letter(dead_letter_id)
      patch("/api/v1/dead-letters/#{dead_letter_id}/resolve", {})
    end

    # ------------------------------------------------------------------
    # Replays
    # ------------------------------------------------------------------

    # Start an event replay.
    def create_replay(topic:, from_date:, to_date:, webhook_id: nil)
      body = { topic: topic, from_date: from_date, to_date: to_date }
      body[:webhook_id] = webhook_id unless webhook_id.nil?
      post("/api/v1/replays", body)
    end

    # List replays.
    def list_replays(limit: 50, cursor: nil)
      get("/api/v1/replays", { limit: limit, cursor: cursor })
    end

    # Get replay details.
    def get_replay(replay_id)
      get("/api/v1/replays/#{replay_id}")
    end

    # Cancel a replay.
    def cancel_replay(replay_id)
      do_delete("/api/v1/replays/#{replay_id}")
    end

    # ------------------------------------------------------------------
    # Jobs
    # ------------------------------------------------------------------

    # Create a scheduled job.
    def create_job(name:, queue:, cron_expression:, **kwargs)
      post("/api/v1/jobs", { name: name, queue: queue, cron_expression: cron_expression, **kwargs })
    end

    # List scheduled jobs.
    def list_jobs(limit: 50, cursor: nil)
      get("/api/v1/jobs", { limit: limit, cursor: cursor })
    end

    # Get job details.
    def get_job(job_id)
      get("/api/v1/jobs/#{job_id}")
    end

    # Update a scheduled job.
    def update_job(job_id, **kwargs)
      patch("/api/v1/jobs/#{job_id}", kwargs)
    end

    # Delete a scheduled job.
    def delete_job(job_id)
      do_delete("/api/v1/jobs/#{job_id}")
    end

    # List runs for a scheduled job.
    def list_job_runs(job_id, limit: 50)
      get("/api/v1/jobs/#{job_id}/runs", { limit: limit })
    end

    # Preview next occurrences for a cron expression.
    def cron_preview(expression, count: 5)
      get("/api/v1/jobs/cron-preview", { expression: expression, count: count })
    end

    # ------------------------------------------------------------------
    # Pipelines
    # ------------------------------------------------------------------

    # Create an event pipeline.
    def create_pipeline(name:, topics:, steps:, **kwargs)
      post("/api/v1/pipelines", { name: name, topics: topics, steps: steps, **kwargs })
    end

    # List pipelines.
    def list_pipelines(limit: 50, cursor: nil)
      get("/api/v1/pipelines", { limit: limit, cursor: cursor })
    end

    # Get pipeline details.
    def get_pipeline(pipeline_id)
      get("/api/v1/pipelines/#{pipeline_id}")
    end

    # Update a pipeline.
    def update_pipeline(pipeline_id, **kwargs)
      patch("/api/v1/pipelines/#{pipeline_id}", kwargs)
    end

    # Delete a pipeline.
    def delete_pipeline(pipeline_id)
      do_delete("/api/v1/pipelines/#{pipeline_id}")
    end

    # Test a pipeline with a sample payload.
    def test_pipeline(pipeline_id, payload)
      post("/api/v1/pipelines/#{pipeline_id}/test", payload)
    end

    # ------------------------------------------------------------------
    # Event Schemas
    # ------------------------------------------------------------------

    # Create an event schema.
    def create_event_schema(topic:, schema:, **kwargs)
      post("/api/v1/event-schemas", { topic: topic, schema: schema, **kwargs })
    end

    # List event schemas.
    def list_event_schemas(limit: 50, cursor: nil)
      get("/api/v1/event-schemas", { limit: limit, cursor: cursor })
    end

    # Get event schema details.
    def get_event_schema(schema_id)
      get("/api/v1/event-schemas/#{schema_id}")
    end

    # Update an event schema.
    def update_event_schema(schema_id, **kwargs)
      patch("/api/v1/event-schemas/#{schema_id}", kwargs)
    end

    # Delete an event schema.
    def delete_event_schema(schema_id)
      do_delete("/api/v1/event-schemas/#{schema_id}")
    end

    # Validate a payload against the schema for a topic.
    def validate_payload(topic, payload)
      post("/api/v1/event-schemas/validate", { topic: topic, payload: payload })
    end

    # ------------------------------------------------------------------
    # Sandbox
    # ------------------------------------------------------------------

    # List sandbox endpoints.
    def list_sandbox_endpoints
      get("/api/v1/sandbox-endpoints")
    end

    # Create a sandbox endpoint.
    def create_sandbox_endpoint(name: nil)
      body = {}
      body[:name] = name unless name.nil?
      post("/api/v1/sandbox-endpoints", body)
    end

    # Delete a sandbox endpoint.
    def delete_sandbox_endpoint(endpoint_id)
      do_delete("/api/v1/sandbox-endpoints/#{endpoint_id}")
    end

    # List requests received by a sandbox endpoint.
    def list_sandbox_requests(endpoint_id, limit: 50)
      get("/api/v1/sandbox-endpoints/#{endpoint_id}/requests", { limit: limit })
    end

    # ------------------------------------------------------------------
    # Analytics
    # ------------------------------------------------------------------

    # Get events per day for the last N days.
    def events_per_day(days: 7)
      get("/api/v1/analytics/events-per-day", { days: days })
    end

    # Get deliveries per day for the last N days.
    def deliveries_per_day(days: 7)
      get("/api/v1/analytics/deliveries-per-day", { days: days })
    end

    # Get top topics by event count.
    def top_topics(limit: 10)
      get("/api/v1/analytics/top-topics", { limit: limit })
    end

    # Get webhook delivery statistics.
    def webhook_stats
      get("/api/v1/analytics/webhook-stats")
    end

    # ------------------------------------------------------------------
    # Project (single / current)
    # ------------------------------------------------------------------

    # Get current project details.
    def get_project
      get("/api/v1/project")
    end

    # Update current project.
    def update_project(**kwargs)
      patch("/api/v1/project", kwargs)
    end

    # List all topics in the current project.
    def list_topics
      get("/api/v1/topics")
    end

    # Get the current API token info.
    def get_token
      get("/api/v1/token")
    end

    # Regenerate the API token.
    def regenerate_token
      post("/api/v1/token/regenerate", {})
    end

    # ------------------------------------------------------------------
    # Projects (multi)
    # ------------------------------------------------------------------

    # List all projects.
    def list_projects
      get("/api/v1/projects")
    end

    # Create a new project.
    def create_project(name)
      post("/api/v1/projects", { name: name })
    end

    # Get project by ID.
    def get_project_by_id(project_id)
      get("/api/v1/projects/#{project_id}")
    end

    # Update a project by ID.
    def update_project_by_id(project_id, **kwargs)
      patch("/api/v1/projects/#{project_id}", kwargs)
    end

    # Delete a project.
    def delete_project(project_id)
      do_delete("/api/v1/projects/#{project_id}")
    end

    # Set a project as the default.
    def set_default_project(project_id)
      patch("/api/v1/projects/#{project_id}/default", {})
    end

    # ------------------------------------------------------------------
    # Teams
    # ------------------------------------------------------------------

    # List members of a project.
    def list_members(project_id)
      get("/api/v1/projects/#{project_id}/members")
    end

    # Add a member to a project.
    def add_member(project_id, email:, role: "member")
      post("/api/v1/projects/#{project_id}/members", { email: email, role: role })
    end

    # Update a member's role.
    def update_member(project_id, member_id, role:)
      patch("/api/v1/projects/#{project_id}/members/#{member_id}", { role: role })
    end

    # Remove a member from a project.
    def remove_member(project_id, member_id)
      do_delete("/api/v1/projects/#{project_id}/members/#{member_id}")
    end

    # ------------------------------------------------------------------
    # Invitations
    # ------------------------------------------------------------------

    # List pending invitations for the current user.
    def list_pending_invitations
      get("/api/v1/invitations/pending")
    end

    # Accept an invitation.
    def accept_invitation(invitation_id)
      post("/api/v1/invitations/#{invitation_id}/accept", {})
    end

    # Reject an invitation.
    def reject_invitation(invitation_id)
      post("/api/v1/invitations/#{invitation_id}/reject", {})
    end

    # ------------------------------------------------------------------
    # Audit
    # ------------------------------------------------------------------

    # List audit log entries.
    def list_audit_logs(limit: 50, cursor: nil)
      get("/api/v1/audit-log", { limit: limit, cursor: cursor })
    end

    # ------------------------------------------------------------------
    # Export
    # ------------------------------------------------------------------

    # Export events as CSV or JSON. Returns raw string.
    def export_events(format: "csv")
      request_raw("GET", "/api/v1/export/events", params: { format: format })
    end

    # Export deliveries as CSV or JSON. Returns raw string.
    def export_deliveries(format: "csv")
      request_raw("GET", "/api/v1/export/deliveries", params: { format: format })
    end

    # Export jobs as CSV or JSON. Returns raw string.
    def export_jobs(format: "csv")
      request_raw("GET", "/api/v1/export/jobs", params: { format: format })
    end

    # Export audit log as CSV or JSON. Returns raw string.
    def export_audit_log(format: "csv")
      request_raw("GET", "/api/v1/export/audit-log", params: { format: format })
    end

    # ------------------------------------------------------------------
    # GDPR
    # ------------------------------------------------------------------

    # Get current user consent status.
    def get_consents
      get("/api/v1/me/consents")
    end

    # Accept consent for a specific purpose.
    def accept_consent(purpose)
      post("/api/v1/me/consents/#{purpose}/accept", {})
    end

    # Export all personal data (GDPR data portability).
    def export_my_data
      get("/api/v1/me/data")
    end

    # Request restriction of data processing.
    def restrict_processing
      post("/api/v1/me/restrict", {})
    end

    # Lift restriction on data processing.
    def lift_restriction
      do_delete("/api/v1/me/restrict")
    end

    # Object to data processing.
    def object_to_processing
      post("/api/v1/me/object", {})
    end

    # Withdraw objection to data processing.
    def restore_consent
      do_delete("/api/v1/me/object")
    end

    # ------------------------------------------------------------------
    # Embed Tokens
    # ------------------------------------------------------------------

    # List embed tokens.
    def list_embed_tokens
      get("/api/v1/embed/tokens")
    end

    # Create an embed token.
    def create_embed_token(config)
      post("/api/v1/embed/tokens", config)
    end

    # Revoke an embed token.
    def revoke_embed_token(id)
      do_delete("/api/v1/embed/tokens/#{id}")
    end

    # ------------------------------------------------------------------
    # Notification Channels
    # ------------------------------------------------------------------

    # Get the notification channel configuration.
    def get_notification_channel
      get("/api/v1/notification-channels")
    end

    # Create or update the notification channel configuration.
    def upsert_notification_channel(config)
      put("/api/v1/notification-channels", config)
    end

    # Delete the notification channel configuration.
    def delete_notification_channel
      do_delete("/api/v1/notification-channels")
    end

    # Test the notification channel configuration.
    def test_notification_channel
      post("/api/v1/notification-channels/test", {})
    end

    # ------------------------------------------------------------------
    # Retention & Purge
    # ------------------------------------------------------------------

    # Get current retention policy.
    def get_retention_policy
      get("/api/v1/retention")
    end

    # Update retention policy.
    def update_retention_policy(policy)
      patch("/api/v1/retention", policy)
    end

    # Preview a purge operation.
    def preview_purge(params)
      post("/api/v1/purge/preview", params)
    end

    # Execute a purge operation.
    def purge_data(params)
      post("/api/v1/purge", params)
    end

    # ------------------------------------------------------------------
    # Health
    # ------------------------------------------------------------------

    # Check API health.
    def health
      get("/health")
    end

    # Get platform status page.
    def status
      get("/status")
    end

    private

    # ------------------------------------------------------------------
    # HTTP helpers
    # ------------------------------------------------------------------

    def get(path, params = nil)
      request("GET", path, params: params)
    end

    def post(path, body)
      request("POST", path, body: body)
    end

    def patch(path, body)
      request("PATCH", path, body: body)
    end

    def put(path, body)
      request("PUT", path, body: body)
    end

    def do_delete(path)
      request("DELETE", path)
    end

    def public_post(path, body)
      uri = build_uri(path)
      http = build_http(uri)

      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(body)

      resp = http.request(req)
      handle_response(resp)
    end

    def request(method, path, params: nil, body: nil)
      uri = build_uri(path, params)
      http = build_http(uri)

      req = build_request(method, uri)
      req["Content-Type"] = "application/json"
      req["X-Api-Key"] = @api_key
      req["Authorization"] = "Bearer #{@auth_token}" if @auth_token
      req.body = JSON.generate(body) if body

      resp = http.request(req)
      handle_response(resp)
    end

    def request_raw(method, path, params: nil)
      uri = build_uri(path, params)
      http = build_http(uri)

      req = build_request(method, uri)
      req["Content-Type"] = "application/json"
      req["X-Api-Key"] = @api_key
      req["Authorization"] = "Bearer #{@auth_token}" if @auth_token

      resp = http.request(req)

      unless resp.is_a?(Net::HTTPSuccess)
        detail = begin
                   parsed = JSON.parse(resp.body)
                   parsed.is_a?(Hash) ? (parsed["error"] || parsed) : parsed
                 rescue JSON::ParserError
                   resp.body
                 end
        raise Jobcelis::Error.new(resp.code.to_i, detail)
      end

      resp.body
    end

    def build_uri(path, params = nil)
      uri = URI("#{@base_url}#{path}")
      if params
        cleaned = params.reject { |_, v| v.nil? }
        uri.query = URI.encode_www_form(cleaned) unless cleaned.empty?
      end
      uri
    end

    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = @timeout
      http.read_timeout = @timeout
      http
    end

    def build_request(method, uri)
      request_path = uri.request_uri
      case method.upcase
      when "GET"    then Net::HTTP::Get.new(request_path)
      when "POST"   then Net::HTTP::Post.new(request_path)
      when "PATCH"  then Net::HTTP::Patch.new(request_path)
      when "PUT"    then Net::HTTP::Put.new(request_path)
      when "DELETE" then Net::HTTP::Delete.new(request_path)
      else raise ArgumentError, "Unsupported HTTP method: #{method}"
      end
    end

    def handle_response(resp)
      unless resp.is_a?(Net::HTTPSuccess)
        detail = begin
                   parsed = JSON.parse(resp.body)
                   parsed.is_a?(Hash) ? (parsed["error"] || parsed) : parsed
                 rescue JSON::ParserError
                   resp.body
                 end
        raise Jobcelis::Error.new(resp.code.to_i, detail)
      end

      return nil if resp.code == "204"

      JSON.parse(resp.body)
    end
  end
end
