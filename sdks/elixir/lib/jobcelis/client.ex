defmodule Jobcelis.Client do
  @moduledoc """
  HTTP client for the Jobcelis API.

  Uses Finch for HTTP requests and Jason for JSON encoding/decoding.
  """

  defstruct [:api_key, :base_url, :auth_token, :finch_name]

  @type t :: %__MODULE__{
          api_key: String.t(),
          base_url: String.t(),
          auth_token: String.t() | nil,
          finch_name: atom()
        }

  @default_base_url "https://jobcelis.com"

  @doc "Create a new client."
  @spec new(String.t(), keyword()) :: t()
  def new(api_key, opts \\ []) do
    %__MODULE__{
      api_key: api_key,
      base_url: Keyword.get(opts, :base_url, @default_base_url) |> String.trim_trailing("/"),
      auth_token: nil,
      finch_name: Keyword.get(opts, :finch_name, Jobcelis.Finch)
    }
  end

  @doc "Set JWT bearer token. Returns updated client."
  @spec set_auth_token(t(), String.t()) :: t()
  def set_auth_token(%__MODULE__{} = client, token) do
    %{client | auth_token: token}
  end

  # ---------------------------------------------------------------------------
  # Auth
  # ---------------------------------------------------------------------------

  def register(%__MODULE__{} = client, email, password, opts \\ []) do
    body = %{email: email, password: password}
    body = if name = Keyword.get(opts, :name), do: Map.put(body, :name, name), else: body
    public_post(client, "/api/v1/auth/register", body)
  end

  def login(%__MODULE__{} = client, email, password) do
    public_post(client, "/api/v1/auth/login", %{email: email, password: password})
  end

  def refresh_token(%__MODULE__{} = client, refresh_token) do
    public_post(client, "/api/v1/auth/refresh", %{refresh_token: refresh_token})
  end

  def verify_mfa(%__MODULE__{} = client, token, code) do
    post(client, "/api/v1/auth/mfa/verify", %{token: token, code: code})
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  def send_event(%__MODULE__{} = client, topic, payload, opts \\ []) do
    body = Map.merge(%{topic: topic, payload: payload}, Map.new(opts))
    post(client, "/api/v1/events", body)
  end

  def send_events(%__MODULE__{} = client, events) do
    post(client, "/api/v1/events/batch", %{events: events})
  end

  def get_event(%__MODULE__{} = client, event_id) do
    get(client, "/api/v1/events/#{event_id}")
  end

  def list_events(%__MODULE__{} = client, opts \\ []) do
    get(client, "/api/v1/events", opts)
  end

  def delete_event(%__MODULE__{} = client, event_id) do
    do_delete(client, "/api/v1/events/#{event_id}")
  end

  # ---------------------------------------------------------------------------
  # Simulate
  # ---------------------------------------------------------------------------

  def simulate_event(%__MODULE__{} = client, topic, payload) do
    post(client, "/api/v1/simulate", %{topic: topic, payload: payload})
  end

  # ---------------------------------------------------------------------------
  # Webhooks
  # ---------------------------------------------------------------------------

  def create_webhook(%__MODULE__{} = client, url, opts \\ []) do
    body = Map.merge(%{url: url}, Map.new(opts))
    post(client, "/api/v1/webhooks", body)
  end

  def get_webhook(%__MODULE__{} = client, webhook_id) do
    get(client, "/api/v1/webhooks/#{webhook_id}")
  end

  def list_webhooks(%__MODULE__{} = client, opts \\ []) do
    get(client, "/api/v1/webhooks", opts)
  end

  def update_webhook(%__MODULE__{} = client, webhook_id, attrs) do
    patch(client, "/api/v1/webhooks/#{webhook_id}", attrs)
  end

  def delete_webhook(%__MODULE__{} = client, webhook_id) do
    do_delete(client, "/api/v1/webhooks/#{webhook_id}")
  end

  def webhook_health(%__MODULE__{} = client, webhook_id) do
    get(client, "/api/v1/webhooks/#{webhook_id}/health")
  end

  def webhook_templates(%__MODULE__{} = client) do
    get(client, "/api/v1/webhooks/templates")
  end

  def test_webhook(%__MODULE__{} = client, webhook_id) do
    post(client, "/api/v1/webhooks/#{webhook_id}/test", %{})
  end

  # ---------------------------------------------------------------------------
  # Deliveries
  # ---------------------------------------------------------------------------

  def list_deliveries(%__MODULE__{} = client, opts \\ []) do
    get(client, "/api/v1/deliveries", opts)
  end

  def retry_delivery(%__MODULE__{} = client, delivery_id) do
    post(client, "/api/v1/deliveries/#{delivery_id}/retry", %{})
  end

  # ---------------------------------------------------------------------------
  # Dead Letters
  # ---------------------------------------------------------------------------

  def list_dead_letters(%__MODULE__{} = client, opts \\ []) do
    get(client, "/api/v1/dead-letters", opts)
  end

  def get_dead_letter(%__MODULE__{} = client, dead_letter_id) do
    get(client, "/api/v1/dead-letters/#{dead_letter_id}")
  end

  def retry_dead_letter(%__MODULE__{} = client, dead_letter_id) do
    post(client, "/api/v1/dead-letters/#{dead_letter_id}/retry", %{})
  end

  def resolve_dead_letter(%__MODULE__{} = client, dead_letter_id) do
    patch(client, "/api/v1/dead-letters/#{dead_letter_id}/resolve", %{})
  end

  # ---------------------------------------------------------------------------
  # Replays
  # ---------------------------------------------------------------------------

  def create_replay(%__MODULE__{} = client, topic, from_date, to_date, opts \\ []) do
    body = %{topic: topic, from_date: from_date, to_date: to_date}
    body = if wh = Keyword.get(opts, :webhook_id), do: Map.put(body, :webhook_id, wh), else: body
    post(client, "/api/v1/replays", body)
  end

  def list_replays(%__MODULE__{} = client, opts \\ []) do
    get(client, "/api/v1/replays", opts)
  end

  def get_replay(%__MODULE__{} = client, replay_id) do
    get(client, "/api/v1/replays/#{replay_id}")
  end

  def cancel_replay(%__MODULE__{} = client, replay_id) do
    do_delete(client, "/api/v1/replays/#{replay_id}")
  end

  # ---------------------------------------------------------------------------
  # Jobs
  # ---------------------------------------------------------------------------

  def create_job(%__MODULE__{} = client, name, queue, cron_expression, opts \\ []) do
    body = Map.merge(%{name: name, queue: queue, cron_expression: cron_expression}, Map.new(opts))
    post(client, "/api/v1/jobs", body)
  end

  def list_jobs(%__MODULE__{} = client, opts \\ []) do
    get(client, "/api/v1/jobs", opts)
  end

  def get_job(%__MODULE__{} = client, job_id) do
    get(client, "/api/v1/jobs/#{job_id}")
  end

  def update_job(%__MODULE__{} = client, job_id, attrs) do
    patch(client, "/api/v1/jobs/#{job_id}", attrs)
  end

  def delete_job(%__MODULE__{} = client, job_id) do
    do_delete(client, "/api/v1/jobs/#{job_id}")
  end

  def list_job_runs(%__MODULE__{} = client, job_id, opts \\ []) do
    get(client, "/api/v1/jobs/#{job_id}/runs", opts)
  end

  def cron_preview(%__MODULE__{} = client, expression, opts \\ []) do
    params = Keyword.merge([expression: expression], opts)
    get(client, "/api/v1/jobs/cron-preview", params)
  end

  # ---------------------------------------------------------------------------
  # Pipelines
  # ---------------------------------------------------------------------------

  def create_pipeline(%__MODULE__{} = client, name, topics, steps, opts \\ []) do
    body = Map.merge(%{name: name, topics: topics, steps: steps}, Map.new(opts))
    post(client, "/api/v1/pipelines", body)
  end

  def list_pipelines(%__MODULE__{} = client, opts \\ []) do
    get(client, "/api/v1/pipelines", opts)
  end

  def get_pipeline(%__MODULE__{} = client, pipeline_id) do
    get(client, "/api/v1/pipelines/#{pipeline_id}")
  end

  def update_pipeline(%__MODULE__{} = client, pipeline_id, attrs) do
    patch(client, "/api/v1/pipelines/#{pipeline_id}", attrs)
  end

  def delete_pipeline(%__MODULE__{} = client, pipeline_id) do
    do_delete(client, "/api/v1/pipelines/#{pipeline_id}")
  end

  def test_pipeline(%__MODULE__{} = client, pipeline_id, payload) do
    post(client, "/api/v1/pipelines/#{pipeline_id}/test", payload)
  end

  # ---------------------------------------------------------------------------
  # Event Schemas
  # ---------------------------------------------------------------------------

  def create_event_schema(%__MODULE__{} = client, topic, schema, opts \\ []) do
    body = Map.merge(%{topic: topic, schema: schema}, Map.new(opts))
    post(client, "/api/v1/event-schemas", body)
  end

  def list_event_schemas(%__MODULE__{} = client, opts \\ []) do
    get(client, "/api/v1/event-schemas", opts)
  end

  def get_event_schema(%__MODULE__{} = client, schema_id) do
    get(client, "/api/v1/event-schemas/#{schema_id}")
  end

  def update_event_schema(%__MODULE__{} = client, schema_id, attrs) do
    patch(client, "/api/v1/event-schemas/#{schema_id}", attrs)
  end

  def delete_event_schema(%__MODULE__{} = client, schema_id) do
    do_delete(client, "/api/v1/event-schemas/#{schema_id}")
  end

  def validate_payload(%__MODULE__{} = client, topic, payload) do
    post(client, "/api/v1/event-schemas/validate", %{topic: topic, payload: payload})
  end

  # ---------------------------------------------------------------------------
  # Sandbox
  # ---------------------------------------------------------------------------

  def list_sandbox_endpoints(%__MODULE__{} = client) do
    get(client, "/api/v1/sandbox-endpoints")
  end

  def create_sandbox_endpoint(%__MODULE__{} = client, opts \\ []) do
    body = if name = Keyword.get(opts, :name), do: %{name: name}, else: %{}
    post(client, "/api/v1/sandbox-endpoints", body)
  end

  def delete_sandbox_endpoint(%__MODULE__{} = client, endpoint_id) do
    do_delete(client, "/api/v1/sandbox-endpoints/#{endpoint_id}")
  end

  def list_sandbox_requests(%__MODULE__{} = client, endpoint_id, opts \\ []) do
    get(client, "/api/v1/sandbox-endpoints/#{endpoint_id}/requests", opts)
  end

  # ---------------------------------------------------------------------------
  # Analytics
  # ---------------------------------------------------------------------------

  def events_per_day(%__MODULE__{} = client, opts \\ []) do
    get(client, "/api/v1/analytics/events-per-day", opts)
  end

  def deliveries_per_day(%__MODULE__{} = client, opts \\ []) do
    get(client, "/api/v1/analytics/deliveries-per-day", opts)
  end

  def top_topics(%__MODULE__{} = client, opts \\ []) do
    get(client, "/api/v1/analytics/top-topics", opts)
  end

  def webhook_stats(%__MODULE__{} = client) do
    get(client, "/api/v1/analytics/webhook-stats")
  end

  # ---------------------------------------------------------------------------
  # Project (current)
  # ---------------------------------------------------------------------------

  def get_project(%__MODULE__{} = client) do
    get(client, "/api/v1/project")
  end

  def update_project(%__MODULE__{} = client, attrs) do
    patch(client, "/api/v1/project", attrs)
  end

  def list_topics(%__MODULE__{} = client) do
    get(client, "/api/v1/topics")
  end

  def get_token(%__MODULE__{} = client) do
    get(client, "/api/v1/token")
  end

  def regenerate_token(%__MODULE__{} = client) do
    post(client, "/api/v1/token/regenerate", %{})
  end

  # ---------------------------------------------------------------------------
  # Projects (multi)
  # ---------------------------------------------------------------------------

  def list_projects(%__MODULE__{} = client) do
    get(client, "/api/v1/projects")
  end

  def create_project(%__MODULE__{} = client, name) do
    post(client, "/api/v1/projects", %{name: name})
  end

  def get_project_by_id(%__MODULE__{} = client, project_id) do
    get(client, "/api/v1/projects/#{project_id}")
  end

  def update_project_by_id(%__MODULE__{} = client, project_id, attrs) do
    patch(client, "/api/v1/projects/#{project_id}", attrs)
  end

  def delete_project(%__MODULE__{} = client, project_id) do
    do_delete(client, "/api/v1/projects/#{project_id}")
  end

  def set_default_project(%__MODULE__{} = client, project_id) do
    patch(client, "/api/v1/projects/#{project_id}/default", %{})
  end

  # ---------------------------------------------------------------------------
  # Teams
  # ---------------------------------------------------------------------------

  def list_members(%__MODULE__{} = client, project_id) do
    get(client, "/api/v1/projects/#{project_id}/members")
  end

  def add_member(%__MODULE__{} = client, project_id, email, opts \\ []) do
    role = Keyword.get(opts, :role, "member")
    post(client, "/api/v1/projects/#{project_id}/members", %{email: email, role: role})
  end

  def update_member(%__MODULE__{} = client, project_id, member_id, role) do
    patch(client, "/api/v1/projects/#{project_id}/members/#{member_id}", %{role: role})
  end

  def remove_member(%__MODULE__{} = client, project_id, member_id) do
    do_delete(client, "/api/v1/projects/#{project_id}/members/#{member_id}")
  end

  # ---------------------------------------------------------------------------
  # Invitations
  # ---------------------------------------------------------------------------

  def list_pending_invitations(%__MODULE__{} = client) do
    get(client, "/api/v1/invitations/pending")
  end

  def accept_invitation(%__MODULE__{} = client, invitation_id) do
    post(client, "/api/v1/invitations/#{invitation_id}/accept", %{})
  end

  def reject_invitation(%__MODULE__{} = client, invitation_id) do
    post(client, "/api/v1/invitations/#{invitation_id}/reject", %{})
  end

  # ---------------------------------------------------------------------------
  # Audit
  # ---------------------------------------------------------------------------

  def list_audit_logs(%__MODULE__{} = client, opts \\ []) do
    get(client, "/api/v1/audit-log", opts)
  end

  # ---------------------------------------------------------------------------
  # Export
  # ---------------------------------------------------------------------------

  def export_events(%__MODULE__{} = client, opts \\ []) do
    get_raw(client, "/api/v1/export/events", opts)
  end

  def export_deliveries(%__MODULE__{} = client, opts \\ []) do
    get_raw(client, "/api/v1/export/deliveries", opts)
  end

  def export_jobs(%__MODULE__{} = client, opts \\ []) do
    get_raw(client, "/api/v1/export/jobs", opts)
  end

  def export_audit_log(%__MODULE__{} = client, opts \\ []) do
    get_raw(client, "/api/v1/export/audit-log", opts)
  end

  # ---------------------------------------------------------------------------
  # GDPR
  # ---------------------------------------------------------------------------

  def get_consents(%__MODULE__{} = client) do
    get(client, "/api/v1/me/consents")
  end

  def accept_consent(%__MODULE__{} = client, purpose) do
    post(client, "/api/v1/me/consents/#{purpose}/accept", %{})
  end

  def export_my_data(%__MODULE__{} = client) do
    get(client, "/api/v1/me/data")
  end

  def restrict_processing(%__MODULE__{} = client) do
    post(client, "/api/v1/me/restrict", %{})
  end

  def lift_restriction(%__MODULE__{} = client) do
    do_delete(client, "/api/v1/me/restrict")
  end

  def object_to_processing(%__MODULE__{} = client) do
    post(client, "/api/v1/me/object", %{})
  end

  def restore_consent(%__MODULE__{} = client) do
    do_delete(client, "/api/v1/me/object")
  end

  # ---------------------------------------------------------------------------
  # Embed Tokens
  # ---------------------------------------------------------------------------

  def list_embed_tokens(%__MODULE__{} = client) do
    get(client, "/api/v1/embed/tokens")
  end

  def create_embed_token(%__MODULE__{} = client, config) do
    post(client, "/api/v1/embed/tokens", config)
  end

  def revoke_embed_token(%__MODULE__{} = client, id) do
    do_delete(client, "/api/v1/embed/tokens/#{id}")
  end

  # ---------------------------------------------------------------------------
  # Notification Channels
  # ---------------------------------------------------------------------------

  def get_notification_channel(%__MODULE__{} = client) do
    get(client, "/api/v1/notification-channels")
  end

  def upsert_notification_channel(%__MODULE__{} = client, config) do
    put(client, "/api/v1/notification-channels", config)
  end

  def delete_notification_channel(%__MODULE__{} = client) do
    do_delete(client, "/api/v1/notification-channels")
  end

  def test_notification_channel(%__MODULE__{} = client) do
    post(client, "/api/v1/notification-channels/test", %{})
  end

  # ---------------------------------------------------------------------------
  # Retention & Purge
  # ---------------------------------------------------------------------------

  def get_retention_policy(%__MODULE__{} = client) do
    get(client, "/api/v1/retention")
  end

  def update_retention_policy(%__MODULE__{} = client, policy) do
    patch(client, "/api/v1/retention", policy)
  end

  def preview_purge(%__MODULE__{} = client, params) do
    post(client, "/api/v1/purge/preview", params)
  end

  def purge_data(%__MODULE__{} = client, params) do
    post(client, "/api/v1/purge", params)
  end

  # ---------------------------------------------------------------------------
  # Health
  # ---------------------------------------------------------------------------

  def health(%__MODULE__{} = client) do
    get(client, "/health")
  end

  def status(%__MODULE__{} = client) do
    get(client, "/status")
  end

  # ===========================================================================
  # Private HTTP helpers
  # ===========================================================================

  defp get(%__MODULE__{} = client, path, params \\ []) do
    request(client, :get, path, params: params)
  end

  defp post(%__MODULE__{} = client, path, body) do
    request(client, :post, path, body: body)
  end

  defp put(%__MODULE__{} = client, path, body) do
    request(client, :put, path, body: body)
  end

  defp patch(%__MODULE__{} = client, path, body) do
    request(client, :patch, path, body: body)
  end

  defp do_delete(%__MODULE__{} = client, path) do
    request(client, :delete, path)
  end

  defp get_raw(%__MODULE__{} = client, path, params \\ []) do
    request_raw(client, :get, path, params: params)
  end

  defp public_post(%__MODULE__{} = client, path, body) do
    url = build_url(client, path)
    headers = [{"content-type", "application/json"}]
    body_json = Jason.encode!(body)

    request = Finch.build(:post, url, headers, body_json)

    case Finch.request(request, client.finch_name) do
      {:ok, %Finch.Response{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, Jason.decode!(resp_body)}

      {:ok, %Finch.Response{status: status, body: resp_body}} ->
        {:error, %Jobcelis.Error{status: status, detail: safe_decode(resp_body)}}

      {:error, reason} ->
        {:error, %Jobcelis.Error{status: 0, detail: reason}}
    end
  end

  defp request(%__MODULE__{} = client, method, path, opts \\ []) do
    params = Keyword.get(opts, :params, [])
    body = Keyword.get(opts, :body)

    url = build_url(client, path, params)
    headers = build_headers(client)
    body_json = if body, do: Jason.encode!(body), else: nil

    request = Finch.build(method, url, headers, body_json)

    case Finch.request(request, client.finch_name) do
      {:ok, %Finch.Response{status: 204}} ->
        :ok

      {:ok, %Finch.Response{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, Jason.decode!(resp_body)}

      {:ok, %Finch.Response{status: status, body: resp_body}} ->
        {:error, %Jobcelis.Error{status: status, detail: safe_decode(resp_body)}}

      {:error, reason} ->
        {:error, %Jobcelis.Error{status: 0, detail: reason}}
    end
  end

  defp request_raw(%__MODULE__{} = client, method, path, opts \\ []) do
    params = Keyword.get(opts, :params, [])
    url = build_url(client, path, params)
    headers = build_headers(client)

    request = Finch.build(method, url, headers)

    case Finch.request(request, client.finch_name) do
      {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, %Jobcelis.Error{status: status, detail: safe_decode(body)}}

      {:error, reason} ->
        {:error, %Jobcelis.Error{status: 0, detail: reason}}
    end
  end

  defp build_url(%__MODULE__{base_url: base_url}, path, params \\ []) do
    params = params |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    if params == [] do
      base_url <> path
    else
      base_url <> path <> "?" <> URI.encode_query(params)
    end
  end

  defp build_headers(%__MODULE__{api_key: api_key, auth_token: auth_token}) do
    headers = [
      {"content-type", "application/json"},
      {"accept", "application/json"},
      {"x-api-key", api_key}
    ]

    if auth_token do
      [{"authorization", "Bearer #{auth_token}"} | headers]
    else
      headers
    end
  end

  defp safe_decode(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> body
    end
  end
end
