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

    # --- HTTP helpers ---

    def _get(self, path: str, params: dict | None = None) -> dict:
        return self._request("GET", path, params=params)

    def _post(self, path: str, body: dict) -> dict:
        return self._request("POST", path, json=body)

    def _patch(self, path: str, body: dict) -> dict:
        return self._request("PATCH", path, json=body)

    def _delete(self, path: str) -> None:
        self._request("DELETE", path)

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
