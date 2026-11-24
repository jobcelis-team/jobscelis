"""Jobcelis Python SDK — API client."""

from __future__ import annotations

import email.utils
import random
import time
import uuid

import requests

RETRYABLE_STATUSES = frozenset({429, 502, 503, 504})
# A POST without an idempotency key is retried only when the server surely did not
# act on it; after a 502/504 it may have, and a retry could create it twice.
NON_IDEMPOTENT_RETRYABLE_STATUSES = frozenset({429, 503})
DEFAULT_MAX_RETRIES = 6
MAX_BACKOFF = 30.0
MAX_RETRY_AFTER = 60.0


class JobcelisError(Exception):
    """Raised when the API returns an error."""

    def __init__(self, status: int, detail):
        self.status = status
        self.detail = detail
        super().__init__(f"HTTP {status}: {detail}")


class JobcelisClient:
    """Client for the Jobcelis Event Infrastructure Platform API."""

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str = "https://jobcelis.com",
        timeout: int = 30,
        max_retries: int = DEFAULT_MAX_RETRIES,
        retry_base_delay: float = 1.0,
        auth_token: str | None = None,
    ):
        """
        ``api_key``: project API key, sent as ``X-Api-Key``. Not needed for the
        ``/auth/*`` calls (register, login, refresh_token, verify_mfa).
        ``auth_token``: user JWT, sent as ``Authorization: Bearer``. Needed for the
        account routes: projects, members, invitations and ``/me/*``.
        ``max_retries``: retries after a network error or HTTP 429/502/503/504
        (default 6, about 60 s of backoff); 0 disables retries. A POST without an
        idempotency key is retried only on 429/503.
        ``retry_base_delay``: base delay in seconds of the exponential backoff.
        """
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.max_retries = max(0, int(max_retries))
        self.retry_base_delay = retry_base_delay
        self._session = requests.Session()
        self._session.headers["Content-Type"] = "application/json"
        if api_key:
            self._session.headers["X-Api-Key"] = api_key
        if auth_token:
            self.set_auth_token(auth_token)

    # --- Auth ---

    def register(self, email: str, password: str, name: str | None = None) -> dict:
        """Register a new account. Does not use API key auth; stores the returned JWT."""
        body = {"email": email, "password": password}
        if name is not None:
            body["name"] = name
        return self._store_token(self._post_public("/api/v1/auth/register", body))

    def login(self, email: str, password: str) -> dict:
        """Log in. Does not use API key auth.

        Returns ``{"user", "token"}`` and stores the token for the account routes, or
        ``{"mfa_required": True, "mfa_token"}`` when the account has MFA: then call
        ``verify_mfa(mfa_token, code)``.
        """
        return self._store_token(
            self._post_public("/api/v1/auth/login", {"email": email, "password": password})
        )

    def refresh_token(self, token: str | None = None) -> dict:
        """Exchange a JWT for a new one (defaults to the stored token) and store it."""
        current = token or self._auth_token()
        if not current:
            raise JobcelisError(0, "No token to refresh: pass one or call set_auth_token()")
        return self._store_token(self._post_public("/api/v1/auth/refresh", {"token": current}))

    def verify_mfa(self, mfa_token: str, code: str) -> dict:
        """Complete an MFA login with the ``mfa_token`` from login() and a TOTP code."""
        return self._store_token(
            self._post_public("/api/v1/auth/mfa/verify", {"mfa_token": mfa_token, "code": code})
        )

    def set_auth_token(self, token: str | None):
        """Set (or clear, with None) the JWT sent as ``Authorization: Bearer``."""
        if token:
            self._session.headers["Authorization"] = f"Bearer {token}"
        else:
            self._session.headers.pop("Authorization", None)

    def _auth_token(self) -> str | None:
        header = self._session.headers.get("Authorization", "")
        return header[len("Bearer "):] if header.startswith("Bearer ") else None

    def _store_token(self, resp):
        if isinstance(resp, dict) and isinstance(resp.get("token"), str) and resp["token"]:
            self.set_auth_token(resp["token"])
        return resp

    # --- Events ---

    def send_event(self, topic: str, payload: dict, **kwargs) -> dict:
        """Send a single event.

        The request carries an ``X-Idempotency-Key`` header (``idempotency_key``
        if given, otherwise a generated UUID) so retries never duplicate the event.
        """
        body = {"topic": topic, "payload": payload, **kwargs}
        key = kwargs.get("idempotency_key") or str(uuid.uuid4())
        return self._request("POST", "/api/v1/events", json=body, idempotency_key=key)

    def send_events(self, events: list[dict]) -> dict:
        """Send up to 1000 events in a batch.

        Items without an ``idempotency_key`` get a generated UUID, so retries never
        duplicate an event.
        """
        items = [
            {**e, "idempotency_key": str(uuid.uuid4())}
            if isinstance(e, dict) and not e.get("idempotency_key")
            else e
            for e in events
        ]
        # every item carries a key, so a retry after a network error is safe
        return self._request("POST", "/api/v1/events/batch", json={"events": items}, idempotent=True)

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

    def create_webhook(self, url: str, rate_limit: dict | None = None, **kwargs) -> dict:
        """Create a webhook."""
        body = {"url": url, **kwargs}
        if rate_limit is not None:
            body["rate_limit"] = rate_limit
        return self._post("/api/v1/webhooks", body)

    def get_webhook(self, webhook_id: str) -> dict:
        """Get webhook details."""
        return self._get(f"/api/v1/webhooks/{webhook_id}")

    def list_webhooks(self, limit: int = 50, cursor: str | None = None) -> dict:
        """List webhooks."""
        return self._get("/api/v1/webhooks", {"limit": limit, "cursor": cursor})

    def update_webhook(self, webhook_id: str, rate_limit: dict | None = None, **kwargs) -> dict:
        """Update a webhook."""
        body = {**kwargs}
        if rate_limit is not None:
            body["rate_limit"] = rate_limit
        return self._patch(f"/api/v1/webhooks/{webhook_id}", body)

    def delete_webhook(self, webhook_id: str) -> None:
        """Deactivate a webhook."""
        self._delete(f"/api/v1/webhooks/{webhook_id}")

    def webhook_health(self, webhook_id: str) -> dict:
        """Get health status for a webhook."""
        return self._get(f"/api/v1/webhooks/{webhook_id}/health")

    def webhook_templates(self) -> dict:
        """List available webhook templates."""
        return self._get("/api/v1/webhooks/templates")

    def test_webhook(self, webhook_id: str) -> dict:
        """Send a test delivery to a webhook."""
        return self._post(f"/api/v1/webhooks/{webhook_id}/test", {})

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

    def create_job(
        self,
        name: str,
        queue: str | None = None,
        cron_expression: str | None = None,
        *,
        topic: str | None = None,
        payload: dict | None = None,
        url: str | None = None,
        method: str | None = None,
        **kwargs,
    ) -> dict:
        """Create a scheduled job.

        ``cron_expression``: a cron expression or "daily" / "weekly" / "monthly".
        The action is ``topic`` (+ ``payload``) to emit an event, ``url`` (+ ``method``,
        ``payload``) to POST to a URL, or the canonical ``action_type`` +
        ``action_config`` in kwargs. ``queue`` is ignored by the server and kept only
        for backwards compatibility.
        """
        if not (topic or url or "action_config" in kwargs):
            raise ValueError("create_job needs topic=, url= or action_config=; otherwise the job does nothing")
        body = {"name": name, **kwargs}
        if cron_expression is not None:
            body["cron_expression"] = cron_expression
        for key, value in (("topic", topic), ("url", url), ("method", method), ("payload", payload)):
            if value is not None:
                body[key] = value
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

    def create_pipeline(
        self,
        name: str,
        topics: list[str],
        steps: list[dict] | None = None,
        *,
        webhook_id: str,
        **kwargs,
    ) -> dict:
        """Create an event pipeline that delivers to ``webhook_id``.

        Steps: ``{"type": "filter", "field", "operator", "value"}``,
        ``{"type": "transform", "operation": "pick" | "remove" | "rename" | "set" |
        "template" | "flatten", ...}`` or ``{"type": "delay", "seconds"}``.
        """
        body = {"name": name, "topics": topics, "steps": steps or [], "webhook_id": webhook_id, **kwargs}
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
        """Run the pipeline's steps on a sample payload (sent as ``{"payload": ...}``)."""
        return self._post(f"/api/v1/pipelines/{pipeline_id}/test", {"payload": payload})

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

    def update_token_restrictions(
        self, scopes: list[str] | None = None, allowed_ips: list[str] | None = None
    ) -> dict:
        """Limit the API token to scopes and client IPs.

        Omitted arguments are left unchanged; an empty ``allowed_ips`` list means any IP.
        """
        body = {k: v for k, v in {"scopes": scopes, "allowed_ips": allowed_ips}.items() if v is not None}
        return self._patch("/api/v1/token", body)

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

    def add_member(self, project_id: str, email: str, role: str = "viewer") -> dict:
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

    def restrict_processing(self, password: str) -> dict:
        """Request restriction of data processing (GDPR Art. 18). Requires your password."""
        return self._post("/api/v1/me/restrict", {"password": password})

    def lift_restriction(self) -> dict:
        """Lift restriction on data processing."""
        self._delete("/api/v1/me/restrict")

    def object_to_processing(self) -> dict:
        """Object to data processing."""
        return self._post("/api/v1/me/object", {})

    def restore_consent(self) -> dict:
        """Withdraw objection to data processing."""
        self._delete("/api/v1/me/object")

    # --- Embed Tokens ---

    def list_embed_tokens(self) -> dict:
        """List embed tokens."""
        return self._get("/api/v1/embed/tokens")

    def create_embed_token(self, config: dict) -> dict:
        """Create an embed token."""
        return self._post("/api/v1/embed/tokens", config)

    def revoke_embed_token(self, id: str) -> None:
        """Revoke an embed token."""
        self._delete(f"/api/v1/embed/tokens/{id}")

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

    # --- Retention & Purge ---

    def get_retention_policy(self) -> dict:
        """Get current retention policy."""
        return self._get("/api/v1/retention")

    def update_retention_policy(self, policy: dict) -> dict:
        """Update the retention policy (sent as ``{"retention_policy": policy}``).

        Keys: ``events_days``, ``deliveries_days``, ``audit_logs_days``.
        """
        return self._patch("/api/v1/retention", {"retention_policy": policy})

    def preview_purge(self, params: dict) -> dict:
        """Preview a purge operation."""
        return self._post("/api/v1/purge/preview", params)

    def purge_data(self, params: dict) -> dict:
        """Execute a purge operation."""
        return self._post("/api/v1/purge", params)

    # --- Health ---

    def health(self) -> dict:
        """Check API health."""
        return self._get("/health")

    def status(self) -> dict:
        """Alias of health(): ``/status`` is an HTML page, so this reads ``/health``."""
        return self._get("/health")

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
        resp = self._send(
            "POST",
            path,
            lambda: requests.post(
                f"{self.base_url}{path}",
                json=body,
                headers={"Content-Type": "application/json"},
                timeout=self.timeout,
            ),
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

    def _session_request(self, method, path, params, idempotency_key=None, idempotent=False, **kwargs):
        if idempotency_key:
            kwargs["headers"] = {**kwargs.get("headers", {}), "X-Idempotency-Key": idempotency_key}
        return self._send(
            method,
            path,
            lambda: self._session.request(
                method,
                f"{self.base_url}{path}",
                params=params,
                timeout=self.timeout,
                **kwargs,
            ),
            idempotent=bool(idempotency_key) or idempotent,
        )

    def _send(self, method: str, path: str, do_request, idempotent: bool = False) -> requests.Response:
        """Run ``do_request``, retrying on network errors and HTTP 429/502/503/504.

        A POST that is not idempotent (no idempotency key) is retried only on 429
        and 503: after a network error, timeout, 502 or 504 the server may have
        acted on it, so a retry could create the resource twice.
        """
        retry_on_network_error = method != "POST" or idempotent
        retryable = RETRYABLE_STATUSES if retry_on_network_error else NON_IDEMPOTENT_RETRYABLE_STATUSES
        attempt = 0
        while True:
            try:
                resp = do_request()
            except (requests.exceptions.ConnectionError, requests.exceptions.Timeout):
                if not retry_on_network_error or attempt >= self.max_retries:
                    raise
                attempt += 1
                time.sleep(self._retry_delay(attempt, None))
                continue
            if resp.status_code in retryable and attempt < self.max_retries:
                attempt += 1
                retry_after = resp.headers.get("Retry-After")
                resp.close()
                time.sleep(self._retry_delay(attempt, retry_after))
                continue
            return resp

    def _retry_delay(self, attempt: int, retry_after: str | None) -> float:
        """Delay in seconds before retry number ``attempt`` (1-based)."""
        if retry_after is not None:
            delay = _parse_retry_after(retry_after)
            if delay is not None:
                return min(MAX_RETRY_AFTER, max(0.0, delay))
        base = min(MAX_BACKOFF, self.retry_base_delay * 2 ** (attempt - 1))
        return base * random.uniform(0.8, 1.2)

    def _request(self, method: str, path: str, **kwargs) -> dict | None:
        params = kwargs.pop("params", None)
        if params:
            params = {k: v for k, v in params.items() if v is not None}

        resp = self._session_request(method, path, params, **kwargs)

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

        resp = self._session_request(method, path, params, **kwargs)

        if not resp.ok:
            try:
                detail = resp.json()
            except ValueError:
                detail = resp.text
            raise JobcelisError(resp.status_code, detail.get("error", detail) if isinstance(detail, dict) else detail)

        return resp.content


def _parse_retry_after(value: str):
    """Seconds to wait from a Retry-After header (seconds or HTTP date), or None."""
    try:
        return float(value)
    except ValueError:
        pass
    try:
        when = email.utils.parsedate_to_datetime(value)
    except (TypeError, ValueError):
        return None
    if when is None:
        return None
    return when.timestamp() - time.time()
