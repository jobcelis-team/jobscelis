defmodule Jobcelis do
  @moduledoc """
  Official Elixir SDK for the [Jobcelis](https://jobcelis.com) Event Infrastructure Platform.

  All API calls go to `https://jobcelis.com` by default — you only need your API key.

  ## Quick Start

      client = Jobcelis.client("your_api_key")
      {:ok, event} = Jobcelis.send_event(client, "order.created", %{order_id: "123"})

  ## Custom URL

  If you're self-hosting Jobcelis:

      client = Jobcelis.client("your_api_key", base_url: "https://your-instance.example.com")
  """

  alias Jobcelis.Client

  @doc """
  Create a new Jobcelis client.

  ## Options

    * `:base_url` - Base URL of the Jobcelis API (default: `"https://jobcelis.com"`)
    * `:finch_name` - Name of the Finch pool to use (default: `Jobcelis.Finch`)

  ## Examples

      client = Jobcelis.client("your_api_key")
      client = Jobcelis.client("your_api_key", base_url: "https://your-instance.example.com")
  """
  @spec client(String.t(), keyword()) :: Client.t()
  defdelegate client(api_key, opts \\ []), to: Client, as: :new

  # ---------------------------------------------------------------------------
  # Auth
  # ---------------------------------------------------------------------------

  @doc "Register a new account. Does not use API key auth."
  defdelegate register(client, email, password, opts \\ []), to: Client

  @doc "Log in and receive JWT + refresh token. Does not use API key auth."
  defdelegate login(client, email, password), to: Client

  @doc "Refresh an expired JWT. Does not use API key auth."
  defdelegate refresh_token(client, refresh_token), to: Client

  @doc "Verify MFA code. Requires auth token set via `set_auth_token/2`."
  defdelegate verify_mfa(client, token, code), to: Client

  @doc "Set JWT bearer token for authenticated requests. Returns updated client."
  defdelegate set_auth_token(client, token), to: Client

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @doc "Send a single event."
  defdelegate send_event(client, topic, payload, opts \\ []), to: Client

  @doc "Send up to 1000 events in a batch."
  defdelegate send_events(client, events), to: Client

  @doc "Get event details."
  defdelegate get_event(client, event_id), to: Client

  @doc "List events with cursor pagination."
  defdelegate list_events(client, opts \\ []), to: Client

  @doc "Delete an event."
  defdelegate delete_event(client, event_id), to: Client

  # ---------------------------------------------------------------------------
  # Simulate
  # ---------------------------------------------------------------------------

  @doc "Simulate sending an event (dry run)."
  defdelegate simulate_event(client, topic, payload), to: Client

  # ---------------------------------------------------------------------------
  # Webhooks
  # ---------------------------------------------------------------------------

  @doc "Create a webhook."
  defdelegate create_webhook(client, url, opts \\ []), to: Client

  @doc "Get webhook details."
  defdelegate get_webhook(client, webhook_id), to: Client

  @doc "List webhooks."
  defdelegate list_webhooks(client, opts \\ []), to: Client

  @doc "Update a webhook."
  defdelegate update_webhook(client, webhook_id, attrs), to: Client

  @doc "Delete a webhook."
  defdelegate delete_webhook(client, webhook_id), to: Client

  @doc "Get health status for a webhook."
  defdelegate webhook_health(client, webhook_id), to: Client

  @doc "List available webhook templates."
  defdelegate webhook_templates(client), to: Client

  # ---------------------------------------------------------------------------
  # Deliveries
  # ---------------------------------------------------------------------------

  @doc "List deliveries."
  defdelegate list_deliveries(client, opts \\ []), to: Client

  @doc "Retry a failed delivery."
  defdelegate retry_delivery(client, delivery_id), to: Client

  # ---------------------------------------------------------------------------
  # Dead Letters
  # ---------------------------------------------------------------------------

  @doc "List dead letters."
  defdelegate list_dead_letters(client, opts \\ []), to: Client

  @doc "Get dead letter details."
  defdelegate get_dead_letter(client, dead_letter_id), to: Client

  @doc "Retry a dead letter."
  defdelegate retry_dead_letter(client, dead_letter_id), to: Client

  @doc "Mark a dead letter as resolved."
  defdelegate resolve_dead_letter(client, dead_letter_id), to: Client

  # ---------------------------------------------------------------------------
  # Replays
  # ---------------------------------------------------------------------------

  @doc "Start an event replay."
  defdelegate create_replay(client, topic, from_date, to_date, opts \\ []), to: Client

  @doc "List replays."
  defdelegate list_replays(client, opts \\ []), to: Client

  @doc "Get replay details."
  defdelegate get_replay(client, replay_id), to: Client

  @doc "Cancel a replay."
  defdelegate cancel_replay(client, replay_id), to: Client

  # ---------------------------------------------------------------------------
  # Jobs
  # ---------------------------------------------------------------------------

  @doc "Create a scheduled job."
  defdelegate create_job(client, name, queue, cron_expression, opts \\ []), to: Client

  @doc "List scheduled jobs."
  defdelegate list_jobs(client, opts \\ []), to: Client

  @doc "Get job details."
  defdelegate get_job(client, job_id), to: Client

  @doc "Update a scheduled job."
  defdelegate update_job(client, job_id, attrs), to: Client

  @doc "Delete a scheduled job."
  defdelegate delete_job(client, job_id), to: Client

  @doc "List runs for a scheduled job."
  defdelegate list_job_runs(client, job_id, opts \\ []), to: Client

  @doc "Preview next occurrences for a cron expression."
  defdelegate cron_preview(client, expression, opts \\ []), to: Client

  # ---------------------------------------------------------------------------
  # Pipelines
  # ---------------------------------------------------------------------------

  @doc "Create an event pipeline."
  defdelegate create_pipeline(client, name, topics, steps, opts \\ []), to: Client

  @doc "List pipelines."
  defdelegate list_pipelines(client, opts \\ []), to: Client

  @doc "Get pipeline details."
  defdelegate get_pipeline(client, pipeline_id), to: Client

  @doc "Update a pipeline."
  defdelegate update_pipeline(client, pipeline_id, attrs), to: Client

  @doc "Delete a pipeline."
  defdelegate delete_pipeline(client, pipeline_id), to: Client

  @doc "Test a pipeline with a sample payload."
  defdelegate test_pipeline(client, pipeline_id, payload), to: Client

  # ---------------------------------------------------------------------------
  # Event Schemas
  # ---------------------------------------------------------------------------

  @doc "Create an event schema."
  defdelegate create_event_schema(client, topic, schema, opts \\ []), to: Client

  @doc "List event schemas."
  defdelegate list_event_schemas(client, opts \\ []), to: Client

  @doc "Get event schema details."
  defdelegate get_event_schema(client, schema_id), to: Client

  @doc "Update an event schema."
  defdelegate update_event_schema(client, schema_id, attrs), to: Client

  @doc "Delete an event schema."
  defdelegate delete_event_schema(client, schema_id), to: Client

  @doc "Validate a payload against the schema for a topic."
  defdelegate validate_payload(client, topic, payload), to: Client

  # ---------------------------------------------------------------------------
  # Sandbox
  # ---------------------------------------------------------------------------

  @doc "List sandbox endpoints."
  defdelegate list_sandbox_endpoints(client), to: Client

  @doc "Create a sandbox endpoint."
  defdelegate create_sandbox_endpoint(client, opts \\ []), to: Client

  @doc "Delete a sandbox endpoint."
  defdelegate delete_sandbox_endpoint(client, endpoint_id), to: Client

  @doc "List requests received by a sandbox endpoint."
  defdelegate list_sandbox_requests(client, endpoint_id, opts \\ []), to: Client

  # ---------------------------------------------------------------------------
  # Analytics
  # ---------------------------------------------------------------------------

  @doc "Get events per day for the last N days."
  defdelegate events_per_day(client, opts \\ []), to: Client

  @doc "Get deliveries per day for the last N days."
  defdelegate deliveries_per_day(client, opts \\ []), to: Client

  @doc "Get top topics by event count."
  defdelegate top_topics(client, opts \\ []), to: Client

  @doc "Get webhook delivery statistics."
  defdelegate webhook_stats(client), to: Client

  # ---------------------------------------------------------------------------
  # Project (current)
  # ---------------------------------------------------------------------------

  @doc "Get current project details."
  defdelegate get_project(client), to: Client

  @doc "Update current project."
  defdelegate update_project(client, attrs), to: Client

  @doc "List all topics in the current project."
  defdelegate list_topics(client), to: Client

  @doc "Get the current API token info."
  defdelegate get_token(client), to: Client

  @doc "Regenerate the API token."
  defdelegate regenerate_token(client), to: Client

  # ---------------------------------------------------------------------------
  # Projects (multi)
  # ---------------------------------------------------------------------------

  @doc "List all projects."
  defdelegate list_projects(client), to: Client

  @doc "Create a new project."
  defdelegate create_project(client, name), to: Client

  @doc "Get project by ID."
  defdelegate get_project_by_id(client, project_id), to: Client

  @doc "Update a project by ID."
  defdelegate update_project_by_id(client, project_id, attrs), to: Client

  @doc "Delete a project."
  defdelegate delete_project(client, project_id), to: Client

  @doc "Set a project as the default."
  defdelegate set_default_project(client, project_id), to: Client

  # ---------------------------------------------------------------------------
  # Teams
  # ---------------------------------------------------------------------------

  @doc "List members of a project."
  defdelegate list_members(client, project_id), to: Client

  @doc "Add a member to a project."
  defdelegate add_member(client, project_id, email, opts \\ []), to: Client

  @doc "Update a member's role."
  defdelegate update_member(client, project_id, member_id, role), to: Client

  @doc "Remove a member from a project."
  defdelegate remove_member(client, project_id, member_id), to: Client

  # ---------------------------------------------------------------------------
  # Invitations
  # ---------------------------------------------------------------------------

  @doc "List pending invitations for the current user."
  defdelegate list_pending_invitations(client), to: Client

  @doc "Accept an invitation."
  defdelegate accept_invitation(client, invitation_id), to: Client

  @doc "Reject an invitation."
  defdelegate reject_invitation(client, invitation_id), to: Client

  # ---------------------------------------------------------------------------
  # Audit
  # ---------------------------------------------------------------------------

  @doc "List audit log entries."
  defdelegate list_audit_logs(client, opts \\ []), to: Client

  # ---------------------------------------------------------------------------
  # Export
  # ---------------------------------------------------------------------------

  @doc "Export events as CSV or JSON. Returns raw binary."
  defdelegate export_events(client, opts \\ []), to: Client

  @doc "Export deliveries as CSV or JSON. Returns raw binary."
  defdelegate export_deliveries(client, opts \\ []), to: Client

  @doc "Export jobs as CSV or JSON. Returns raw binary."
  defdelegate export_jobs(client, opts \\ []), to: Client

  @doc "Export audit log as CSV or JSON. Returns raw binary."
  defdelegate export_audit_log(client, opts \\ []), to: Client

  # ---------------------------------------------------------------------------
  # GDPR
  # ---------------------------------------------------------------------------

  @doc "Get current user consent status."
  defdelegate get_consents(client), to: Client

  @doc "Accept consent for a specific purpose."
  defdelegate accept_consent(client, purpose), to: Client

  @doc "Export all personal data (GDPR data portability)."
  defdelegate export_my_data(client), to: Client

  @doc "Request restriction of data processing."
  defdelegate restrict_processing(client), to: Client

  @doc "Lift restriction on data processing."
  defdelegate lift_restriction(client), to: Client

  @doc "Object to data processing."
  defdelegate object_to_processing(client), to: Client

  @doc "Withdraw objection to data processing."
  defdelegate restore_consent(client), to: Client

  # ---------------------------------------------------------------------------
  # Health
  # ---------------------------------------------------------------------------

  @doc "Check API health."
  defdelegate health(client), to: Client

  @doc "Get platform status."
  defdelegate status(client), to: Client
end
