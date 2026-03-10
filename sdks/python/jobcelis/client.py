"""Jobcelis Python SDK — API client."""

import requests


class JobcelisError(Exception):
    """Raised when the API returns an error."""

    def __init__(self, status: int, detail):
        self.status = status
        self.detail = detail
        super().__init__(f"HTTP {status}: {detail}")


class JobcelisClient:
    """Client for the Jobcelis Event Infrastructure Platform API."""

    def __init__(self, api_key: str, base_url: str = "https://jobcelis.com", timeout: int = 30):
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self._session = requests.Session()
        self._session.headers.update({
            "Content-Type": "application/json",
            "X-Api-Key": self.api_key,
        })

    # --- Auth ---

    def register(self, email: str, password: str, name: str | None = None) -> dict:
        """Register a new account. Does not use API key auth."""
        body = {"email": email, "password": password}
        if name is not None:
            body["name"] = name
        return self._post_public("/api/v1/auth/register", body)

    def login(self, email: str, password: str) -> dict:
        """Log in and receive JWT + refresh token. Does not use API key auth."""
        return self._post_public("/api/v1/auth/login", {"email": email, "password": password})

    def refresh_token(self, refresh_token: str) -> dict:
        """Refresh an expired JWT using a refresh token. Does not use API key auth."""
        return self._post_public("/api/v1/auth/refresh", {"refresh_token": refresh_token})

    def verify_mfa(self, token: str, code: str) -> dict:
        """Verify MFA code. Requires Bearer token set via set_auth_token()."""
        return self._post("/api/v1/auth/mfa/verify", {"token": token, "code": code})

    def set_auth_token(self, token: str):
        """Set JWT bearer token for authenticated requests."""
        self._session.headers["Authorization"] = f"Bearer {token}"

    # --- Events ---

    def send_event(self, topic: str, payload: dict, **kwargs) -> dict:
        """Send a single event."""
        body = {"topic": topic, "payload": payload, **kwargs}
        return self._post("/api/v1/events", body)

    def send_events(self, events: list[dict]) -> dict:
        """Send up to 1000 events in a batch."""
        return self._post("/api/v1/events/batch", {"events": events})

    def get_event(self, event_id: str) -> dict:
        """Get event details."""
        return self._get(f"/api/v1/events/{event_id}")

    def list_events(self, limit: int = 50, cursor: str | None = None) -> dict:
        """List events with cursor pagination."""
        return self._get("/api/v1/events", {"limit": limit, "cursor": cursor})

    def delete_event(self, event_id: str) -> None:
        """Deactivate an event."""
        self._delete(f"/api/v1/events/{event_id}")

    # --- Webhooks ---

    def create_webhook(self, url: str, **kwargs) -> dict:
        """Create a webhook."""
        body = {"url": url, **kwargs}
        return self._post("/api/v1/webhooks", body)

    def get_webhook(self, webhook_id: str) -> dict:
        """Get webhook details."""
        return self._get(f"/api/v1/webhooks/{webhook_id}")

    def list_webhooks(self, limit: int = 50, cursor: str | None = None) -> dict:
        """List webhooks."""
        return self._get("/api/v1/webhooks", {"limit": limit, "cursor": cursor})

    def update_webhook(self, webhook_id: str, **kwargs) -> dict:
        """Update a webhook."""
        return self._patch(f"/api/v1/webhooks/{webhook_id}", kwargs)

    def delete_webhook(self, webhook_id: str) -> None:
        """Deactivate a webhook."""
        self._delete(f"/api/v1/webhooks/{webhook_id}")

    def webhook_health(self, webhook_id: str) -> dict:
        """Get health status for a webhook."""
        return self._get(f"/api/v1/webhooks/{webhook_id}/health")

    def webhook_templates(self) -> dict:
        """List available webhook templates."""
        return self._get("/api/v1/webhooks/templates")

    # --- Deliveries ---

    def list_deliveries(self, limit: int = 50, cursor: str | None = None, **filters) -> dict:
        """List deliveries."""
        params = {"limit": limit, "cursor": cursor, **filters}
        return self._get("/api/v1/deliveries", params)

    def retry_delivery(self, delivery_id: str) -> None:
        """Retry a failed delivery."""
        self._post(f"/api/v1/deliveries/{delivery_id}/retry", {})

    # --- Dead Letters ---

    def list_dead_letters(self, limit: int = 50, cursor: str | None = None) -> dict:
        """List dead letters."""
        return self._get("/api/v1/dead-letters", {"limit": limit, "cursor": cursor})

    def get_dead_letter(self, dead_letter_id: str) -> dict:
        """Get dead letter details."""
        return self._get(f"/api/v1/dead-letters/{dead_letter_id}")

    def retry_dead_letter(self, dead_letter_id: str) -> None:
        """Retry a dead letter."""
        self._post(f"/api/v1/dead-letters/{dead_letter_id}/retry", {})

    def resolve_dead_letter(self, dead_letter_id: str) -> None:
        """Mark a dead letter as resolved."""
        self._patch(f"/api/v1/dead-letters/{dead_letter_id}/resolve", {})

    # --- Replays ---

    def create_replay(self, topic: str, from_date: str, to_date: str, webhook_id: str | None = None) -> dict:
        """Start an event replay."""
        body = {"topic": topic, "from_date": from_date, "to_date": to_date}
        if webhook_id:
            body["webhook_id"] = webhook_id
        return self._post("/api/v1/replays", body)

    def list_replays(self, limit: int = 50, cursor: str | None = None) -> dict:
        """List replays."""
        return self._get("/api/v1/replays", {"limit": limit, "cursor": cursor})

    def get_replay(self, replay_id: str) -> dict:
        """Get replay details."""
        return self._get(f"/api/v1/replays/{replay_id}")

    def cancel_replay(self, replay_id: str) -> None:
        """Cancel a replay."""
        self._delete(f"/api/v1/replays/{replay_id}")

    # --- Jobs ---

    def create_job(self, name: str, queue: str, cron_expression: str, **kwargs) -> dict:
        """Create a scheduled job."""
        body = {"name": name, "queue": queue, "cron_expression": cron_expression, **kwargs}
        return self._post("/api/v1/jobs", body)

    def list_jobs(self, limit: int = 50, cursor: str | None = None) -> dict:
        """List scheduled jobs."""
        return self._get("/api/v1/jobs", {"limit": limit, "cursor": cursor})

    def get_job(self, job_id: str) -> dict:
        """Get job details."""
        return self._get(f"/api/v1/jobs/{job_id}")

    def update_job(self, job_id: str, **kwargs) -> dict:
        """Update a scheduled job."""
        return self._patch(f"/api/v1/jobs/{job_id}", kwargs)

    def delete_job(self, job_id: str) -> None:
        """Delete a scheduled job."""
        self._delete(f"/api/v1/jobs/{job_id}")

    def list_job_runs(self, job_id: str, limit: int = 50) -> dict:
        """List runs for a scheduled job."""
        return self._get(f"/api/v1/jobs/{job_id}/runs", {"limit": limit})

    def cron_preview(self, expression: str, count: int = 5) -> dict:
        """Preview next occurrences for a cron expression."""
        return self._get("/api/v1/jobs/cron-preview", {"expression": expression, "count": count})

    # --- Pipelines ---

    def create_pipeline(self, name: str, topics: list[str], steps: list[dict], **kwargs) -> dict:
        """Create an event pipeline."""
        body = {"name": name, "topics": topics, "steps": steps, **kwargs}
        return self._post("/api/v1/pipelines", body)

    def list_pipelines(self, limit: int = 50, cursor: str | None = None) -> dict:
        """List pipelines."""
        return self._get("/api/v1/pipelines", {"limit": limit, "cursor": cursor})

    def get_pipeline(self, pipeline_id: str) -> dict:
        """Get pipeline details."""
        return self._get(f"/api/v1/pipelines/{pipeline_id}")

    def update_pipeline(self, pipeline_id: str, **kwargs) -> dict:
        """Update a pipeline."""
        return self._patch(f"/api/v1/pipelines/{pipeline_id}", kwargs)

    def delete_pipeline(self, pipeline_id: str) -> None:
        """Delete a pipeline."""
        self._delete(f"/api/v1/pipelines/{pipeline_id}")

    def test_pipeline(self, pipeline_id: str, payload: dict) -> dict:
        """Test a pipeline with a sample payload."""
        return self._post(f"/api/v1/pipelines/{pipeline_id}/test", payload)

    # --- Event Schemas ---

    def create_event_schema(self, topic: str, schema: dict, **kwargs) -> dict:
        """Create an event schema."""
        body = {"topic": topic, "schema": schema, **kwargs}
        return self._post("/api/v1/event-schemas", body)

    def list_event_schemas(self, limit: int = 50, cursor: str | None = None) -> dict:
        """List event schemas."""
        return self._get("/api/v1/event-schemas", {"limit": limit, "cursor": cursor})

    def get_event_schema(self, schema_id: str) -> dict:
        """Get event schema details."""
        return self._get(f"/api/v1/event-schemas/{schema_id}")

    def update_event_schema(self, schema_id: str, **kwargs) -> dict:
        """Update an event schema."""
        return self._patch(f"/api/v1/event-schemas/{schema_id}", kwargs)

    def delete_event_schema(self, schema_id: str) -> None:
        """Delete an event schema."""
        self._delete(f"/api/v1/event-schemas/{schema_id}")

    def validate_payload(self, topic: str, payload: dict) -> dict:
        """Validate a payload against the schema for a topic."""
        return self._post("/api/v1/event-schemas/validate", {"topic": topic, "payload": payload})

    # --- Sandbox ---

    def list_sandbox_endpoints(self) -> dict:
        """List sandbox endpoints."""
        return self._get("/api/v1/sandbox-endpoints")

    def create_sandbox_endpoint(self, name: str | None = None) -> dict:
        """Create a sandbox endpoint."""
        body = {}
        if name is not None:
            body["name"] = name
        return self._post("/api/v1/sandbox-endpoints", body)

    def delete_sandbox_endpoint(self, endpoint_id: str) -> None:
        """Delete a sandbox endpoint."""
        self._delete(f"/api/v1/sandbox-endpoints/{endpoint_id}")

    def list_sandbox_requests(self, endpoint_id: str, limit: int = 50) -> dict:
        """List requests received by a sandbox endpoint."""
        return self._get(f"/api/v1/sandbox-endpoints/{endpoint_id}/requests", {"limit": limit})

    # --- Analytics ---

    def events_per_day(self, days: int = 7) -> dict:
        """Get events per day for the last N days."""
        return self._get("/api/v1/analytics/events-per-day", {"days": days})

    def deliveries_per_day(self, days: int = 7) -> dict:
        """Get deliveries per day for the last N days."""
        return self._get("/api/v1/analytics/deliveries-per-day", {"days": days})

    def top_topics(self, limit: int = 10) -> dict:
        """Get top topics by event count."""
        return self._get("/api/v1/analytics/top-topics", {"limit": limit})

    def webhook_stats(self) -> dict:
        """Get webhook delivery statistics."""
        return self._get("/api/v1/analytics/webhook-stats")

    # --- Project (single / current) ---

    def get_project(self) -> dict:
        """Get current project details."""
        return self._get("/api/v1/project")

    def update_project(self, **kwargs) -> dict:
        """Update current project."""
        return self._patch("/api/v1/project", kwargs)

    def list_topics(self) -> dict:
        """List all topics in the current project."""
        return self._get("/api/v1/topics")

    def get_token(self) -> dict:
        """Get the current API token info."""
        return self._get("/api/v1/token")

    def regenerate_token(self) -> dict:
        """Regenerate the API token."""
        return self._post("/api/v1/token/regenerate", {})

    # --- Projects (multi) ---

    def list_projects(self) -> dict:
        """List all projects."""
        return self._get("/api/v1/projects")

    def create_project(self, name: str) -> dict:
        """Create a new project."""
        return self._post("/api/v1/projects", {"name": name})

    def get_project_by_id(self, project_id: str) -> dict:
        """Get project by ID."""
        return self._get(f"/api/v1/projects/{project_id}")

    def update_project_by_id(self, project_id: str, **kwargs) -> dict:
        """Update a project by ID."""
        return self._patch(f"/api/v1/projects/{project_id}", kwargs)

    def delete_project(self, project_id: str) -> None:
        """Delete a project."""
        self._delete(f"/api/v1/projects/{project_id}")

    def set_default_project(self, project_id: str) -> dict:
        """Set a project as the default."""
        return self._patch(f"/api/v1/projects/{project_id}/default", {})

    # --- Teams ---

    def list_members(self, project_id: str) -> dict:
        """List members of a project."""
        return self._get(f"/api/v1/projects/{project_id}/members")

    def add_member(self, project_id: str, email: str, role: str = "member") -> dict:
        """Add a member to a project."""
        return self._post(f"/api/v1/projects/{project_id}/members", {"email": email, "role": role})

    def update_member(self, project_id: str, member_id: str, role: str) -> dict:
        """Update a member's role."""
        return self._patch(f"/api/v1/projects/{project_id}/members/{member_id}", {"role": role})

    def remove_member(self, project_id: str, member_id: str) -> None:
        """Remove a member from a project."""
        self._delete(f"/api/v1/projects/{project_id}/members/{member_id}")

    # --- Invitations ---

    def list_pending_invitations(self) -> dict:
        """List pending invitations for the current user."""
        return self._get("/api/v1/invitations/pending")

    def accept_invitation(self, invitation_id: str) -> dict:
        """Accept an invitation."""
        return self._post(f"/api/v1/invitations/{invitation_id}/accept", {})

    def reject_invitation(self, invitation_id: str) -> dict:
        """Reject an invitation."""
        return self._post(f"/api/v1/invitations/{invitation_id}/reject", {})

    # --- Audit ---

    def list_audit_logs(self, limit: int = 50, cursor: str | None = None) -> dict:
        """List audit log entries."""
        return self._get("/api/v1/audit-log", {"limit": limit, "cursor": cursor})

    # --- Export ---

    def export_events(self, format: str = "csv") -> bytes:
        """Export events as CSV or JSON. Returns raw bytes."""
        return self._request_raw("GET", "/api/v1/export/events", params={"format": format})

    def export_deliveries(self, format: str = "csv") -> bytes:
        """Export deliveries as CSV or JSON. Returns raw bytes."""
        return self._request_raw("GET", "/api/v1/export/deliveries", params={"format": format})

    def export_jobs(self, format: str = "csv") -> bytes:
        """Export jobs as CSV or JSON. Returns raw bytes."""
        return self._request_raw("GET", "/api/v1/export/jobs", params={"format": format})

    def export_audit_log(self, format: str = "csv") -> bytes:
        """Export audit log as CSV or JSON. Returns raw bytes."""
        return self._request_raw("GET", "/api/v1/export/audit-log", params={"format": format})

    # --- Simulate ---

    def simulate_event(self, topic: str, payload: dict) -> dict:
        """Simulate sending an event (dry run)."""
        return self._post("/api/v1/simulate", {"topic": topic, "payload": payload})

    # --- GDPR ---

    def get_consents(self) -> dict:
        """Get current user consent status."""
        return self._get("/api/v1/me/consents")

    def accept_consent(self, purpose: str) -> dict:
        """Accept consent for a specific purpose."""
        return self._post(f"/api/v1/me/consents/{purpose}/accept", {})

    def export_my_data(self) -> dict:
        """Export all personal data (GDPR data portability)."""
        return self._get("/api/v1/me/data")

    def restrict_processing(self) -> dict:
        """Request restriction of data processing."""
        return self._post("/api/v1/me/restrict", {})

    def lift_restriction(self) -> dict:
        """Lift restriction on data processing."""
        self._delete("/api/v1/me/restrict")

    def object_to_processing(self) -> dict:
        """Object to data processing."""
        return self._post("/api/v1/me/object", {})

    def restore_consent(self) -> dict:
        """Withdraw objection to data processing."""
        self._delete("/api/v1/me/object")

    # --- Notification Channels ---

    def get_notification_channel(self) -> dict:
        """Get notification channel configuration."""
        return self._get("/api/v1/notification-channels")

    def upsert_notification_channel(self, config: dict) -> dict:
        """Create or update notification channel configuration."""
        return self._put("/api/v1/notification-channels", config)

    def delete_notification_channel(self) -> None:
        """Delete notification channel configuration."""
        self._delete("/api/v1/notification-channels")

    def test_notification_channel(self) -> dict:
        """Send a test notification to the configured channel."""
        return self._post("/api/v1/notification-channels/test", {})

    # --- Health ---

    def health(self) -> dict:
        """Check API health."""
        return self._get("/health")

    def status(self) -> dict:
        """Get platform status page."""
        return self._get("/status")

    # --- HTTP helpers ---

    def _get(self, path: str, params: dict | None = None) -> dict:
        return self._request("GET", path, params=params)

    def _post(self, path: str, body: dict) -> dict:
        return self._request("POST", path, json=body)

    def _put(self, path: str, body: dict) -> dict:
        return self._request("PUT", path, json=body)

    def _patch(self, path: str, body: dict) -> dict:
        return self._request("PATCH", path, json=body)

    def _delete(self, path: str) -> None:
        self._request("DELETE", path)

    def _post_public(self, path: str, body: dict) -> dict:
        """POST without X-Api-Key header (for public auth endpoints)."""
        resp = requests.post(
            f"{self.base_url}{path}",
            json=body,
            headers={"Content-Type": "application/json"},
            timeout=self.timeout,
        )
        if not resp.ok:
            try:
                detail = resp.json()
            except ValueError:
                detail = resp.text
            raise JobcelisError(resp.status_code, detail.get("error", detail) if isinstance(detail, dict) else detail)
        if resp.status_code == 204:
            return None
        return resp.json()

    def _request(self, method: str, path: str, **kwargs) -> dict | None:
        params = kwargs.pop("params", None)
        if params:
            params = {k: v for k, v in params.items() if v is not None}

        resp = self._session.request(
            method,
            f"{self.base_url}{path}",
            params=params,
            timeout=self.timeout,
            **kwargs,
        )

        if not resp.ok:
            try:
                detail = resp.json()
            except ValueError:
                detail = resp.text
            raise JobcelisError(resp.status_code, detail.get("error", detail) if isinstance(detail, dict) else detail)

        if resp.status_code == 204:
            return None
        return resp.json()

    def _request_raw(self, method: str, path: str, **kwargs) -> bytes:
        """Like _request but returns raw bytes instead of parsed JSON."""
        params = kwargs.pop("params", None)
        if params:
            params = {k: v for k, v in params.items() if v is not None}

        resp = self._session.request(
            method,
            f"{self.base_url}{path}",
            params=params,
            timeout=self.timeout,
            **kwargs,
        )

        if not resp.ok:
            try:
                detail = resp.json()
            except ValueError:
                detail = resp.text
            raise JobcelisError(resp.status_code, detail.get("error", detail) if isinstance(detail, dict) else detail)

        return resp.content
