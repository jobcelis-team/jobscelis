use reqwest::{Client, Method, Response};
use serde_json::{json, Value};

use crate::error::JobcelisError;

/// Client for the Jobcelis Event Infrastructure Platform API.
///
/// All API calls go to `https://jobcelis.com` by default.
pub struct JobcelisClient {
    http: Client,
    api_key: String,
    base_url: String,
    auth_token: Option<String>,
}

impl JobcelisClient {
    /// Create a new client with the given API key.
    /// Connects to `https://jobcelis.com` by default.
    pub fn new(api_key: &str) -> Self {
        Self {
            http: Client::new(),
            api_key: api_key.to_string(),
            base_url: "https://jobcelis.com".to_string(),
            auth_token: None,
        }
    }

    /// Create a new client with a custom base URL.
    pub fn with_base_url(api_key: &str, base_url: &str) -> Self {
        Self {
            http: Client::new(),
            api_key: api_key.to_string(),
            base_url: base_url.trim_end_matches('/').to_string(),
            auth_token: None,
        }
    }

    /// Set JWT bearer token for authenticated requests.
    pub fn set_auth_token(&mut self, token: &str) {
        self.auth_token = Some(token.to_string());
    }

    // -------------------------------------------------------------------------
    // Auth
    // -------------------------------------------------------------------------

    /// Register a new account. Does not use API key auth.
    pub async fn register(&self, email: &str, password: &str, name: Option<&str>) -> Result<Value, JobcelisError> {
        let mut body = json!({"email": email, "password": password});
        if let Some(n) = name {
            body["name"] = json!(n);
        }
        self.public_post("/api/v1/auth/register", body).await
    }

    /// Log in and receive JWT + refresh token.
    pub async fn login(&self, email: &str, password: &str) -> Result<Value, JobcelisError> {
        self.public_post("/api/v1/auth/login", json!({"email": email, "password": password})).await
    }

    /// Refresh an expired JWT.
    pub async fn refresh_token(&self, refresh_token: &str) -> Result<Value, JobcelisError> {
        self.public_post("/api/v1/auth/refresh", json!({"refresh_token": refresh_token})).await
    }

    /// Verify MFA code.
    pub async fn verify_mfa(&self, token: &str, code: &str) -> Result<Value, JobcelisError> {
        self.post("/api/v1/auth/mfa/verify", json!({"token": token, "code": code})).await
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// Send a single event.
    pub async fn send_event(&self, topic: &str, payload: Value) -> Result<Value, JobcelisError> {
        self.post("/api/v1/events", json!({"topic": topic, "payload": payload})).await
    }

    /// Send up to 1000 events in a batch.
    pub async fn send_events(&self, events: Vec<Value>) -> Result<Value, JobcelisError> {
        self.post("/api/v1/events/batch", json!({"events": events})).await
    }

    /// Get event details.
    pub async fn get_event(&self, event_id: &str) -> Result<Value, JobcelisError> {
        self.get(&format!("/api/v1/events/{event_id}"), &[]).await
    }

    /// List events with cursor pagination.
    pub async fn list_events(&self, limit: u32, cursor: Option<&str>) -> Result<Value, JobcelisError> {
        let mut params: Vec<(&str, String)> = vec![("limit", limit.to_string())];
        if let Some(c) = cursor { params.push(("cursor", c.to_string())); }
        self.get("/api/v1/events", &params).await
    }

    /// Delete an event.
    pub async fn delete_event(&self, event_id: &str) -> Result<(), JobcelisError> {
        self.do_delete(&format!("/api/v1/events/{event_id}")).await
    }

    // -------------------------------------------------------------------------
    // Simulate
    // -------------------------------------------------------------------------

    /// Simulate sending an event (dry run).
    pub async fn simulate_event(&self, topic: &str, payload: Value) -> Result<Value, JobcelisError> {
        self.post("/api/v1/simulate", json!({"topic": topic, "payload": payload})).await
    }

    // -------------------------------------------------------------------------
    // Webhooks
    // -------------------------------------------------------------------------

    /// Create a webhook.
    ///
    /// Optional fields via `extra`: `topics`, `secret`, `headers`, `rate_limit`.
    /// The `rate_limit` object accepts `max_per_second` and/or `max_per_minute`:
    /// ```ignore
    /// client.create_webhook("https://example.com/hook", Some(json!({
    ///     "rate_limit": { "max_per_second": 10, "max_per_minute": 100 }
    /// }))).await?;
    /// ```
    pub async fn create_webhook(&self, url: &str, extra: Option<Value>) -> Result<Value, JobcelisError> {
        let mut body = json!({"url": url});
        if let Some(e) = extra {
            if let Value::Object(map) = e {
                for (k, v) in map { body[k] = v; }
            }
        }
        self.post("/api/v1/webhooks", body).await
    }

    /// Get webhook details.
    pub async fn get_webhook(&self, webhook_id: &str) -> Result<Value, JobcelisError> {
        self.get(&format!("/api/v1/webhooks/{webhook_id}"), &[]).await
    }

    /// List webhooks.
    pub async fn list_webhooks(&self, limit: u32, cursor: Option<&str>) -> Result<Value, JobcelisError> {
        let mut params: Vec<(&str, String)> = vec![("limit", limit.to_string())];
        if let Some(c) = cursor { params.push(("cursor", c.to_string())); }
        self.get("/api/v1/webhooks", &params).await
    }

    /// Update a webhook.
    ///
    /// The `data` object can include `url`, `topics`, `secret`, `headers`, `rate_limit`.
    /// The `rate_limit` object accepts `max_per_second` and/or `max_per_minute`:
    /// ```ignore
    /// client.update_webhook("wh_123", json!({
    ///     "rate_limit": { "max_per_second": 5, "max_per_minute": 60 }
    /// })).await?;
    /// ```
    pub async fn update_webhook(&self, webhook_id: &str, data: Value) -> Result<Value, JobcelisError> {
        self.patch(&format!("/api/v1/webhooks/{webhook_id}"), data).await
    }

    /// Delete a webhook.
    pub async fn delete_webhook(&self, webhook_id: &str) -> Result<(), JobcelisError> {
        self.do_delete(&format!("/api/v1/webhooks/{webhook_id}")).await
    }

    /// Get health status for a webhook.
    pub async fn webhook_health(&self, webhook_id: &str) -> Result<Value, JobcelisError> {
        self.get(&format!("/api/v1/webhooks/{webhook_id}/health"), &[]).await
    }

    /// List available webhook templates.
    pub async fn webhook_templates(&self) -> Result<Value, JobcelisError> {
        self.get("/api/v1/webhooks/templates", &[]).await
    }

    // -------------------------------------------------------------------------
    // Deliveries
    // -------------------------------------------------------------------------

    /// List deliveries.
    pub async fn list_deliveries(&self, limit: u32, cursor: Option<&str>, status: Option<&str>) -> Result<Value, JobcelisError> {
        let mut params: Vec<(&str, String)> = vec![("limit", limit.to_string())];
        if let Some(c) = cursor { params.push(("cursor", c.to_string())); }
        if let Some(s) = status { params.push(("status", s.to_string())); }
        self.get("/api/v1/deliveries", &params).await
    }

    /// Retry a failed delivery.
    pub async fn retry_delivery(&self, delivery_id: &str) -> Result<Value, JobcelisError> {
        self.post(&format!("/api/v1/deliveries/{delivery_id}/retry"), json!({})).await
    }

    // -------------------------------------------------------------------------
    // Dead Letters
    // -------------------------------------------------------------------------

    /// List dead letters.
    pub async fn list_dead_letters(&self, limit: u32, cursor: Option<&str>) -> Result<Value, JobcelisError> {
        let mut params: Vec<(&str, String)> = vec![("limit", limit.to_string())];
        if let Some(c) = cursor { params.push(("cursor", c.to_string())); }
        self.get("/api/v1/dead-letters", &params).await
    }

    /// Get dead letter details.
    pub async fn get_dead_letter(&self, dead_letter_id: &str) -> Result<Value, JobcelisError> {
        self.get(&format!("/api/v1/dead-letters/{dead_letter_id}"), &[]).await
    }

    /// Retry a dead letter.
    pub async fn retry_dead_letter(&self, dead_letter_id: &str) -> Result<Value, JobcelisError> {
        self.post(&format!("/api/v1/dead-letters/{dead_letter_id}/retry"), json!({})).await
    }

    /// Mark a dead letter as resolved.
    pub async fn resolve_dead_letter(&self, dead_letter_id: &str) -> Result<Value, JobcelisError> {
        self.patch(&format!("/api/v1/dead-letters/{dead_letter_id}/resolve"), json!({})).await
    }

    // -------------------------------------------------------------------------
    // Replays
    // -------------------------------------------------------------------------

    /// Start an event replay.
    pub async fn create_replay(&self, topic: &str, from_date: &str, to_date: &str, webhook_id: Option<&str>) -> Result<Value, JobcelisError> {
        let mut body = json!({"topic": topic, "from_date": from_date, "to_date": to_date});
        if let Some(wh) = webhook_id { body["webhook_id"] = json!(wh); }
        self.post("/api/v1/replays", body).await
    }

    /// List replays.
    pub async fn list_replays(&self, limit: u32, cursor: Option<&str>) -> Result<Value, JobcelisError> {
        let mut params: Vec<(&str, String)> = vec![("limit", limit.to_string())];
        if let Some(c) = cursor { params.push(("cursor", c.to_string())); }
        self.get("/api/v1/replays", &params).await
    }

    /// Get replay details.
    pub async fn get_replay(&self, replay_id: &str) -> Result<Value, JobcelisError> {
        self.get(&format!("/api/v1/replays/{replay_id}"), &[]).await
    }

    /// Cancel a replay.
    pub async fn cancel_replay(&self, replay_id: &str) -> Result<(), JobcelisError> {
        self.do_delete(&format!("/api/v1/replays/{replay_id}")).await
    }

    // -------------------------------------------------------------------------
    // Jobs
    // -------------------------------------------------------------------------

    /// Create a scheduled job.
    pub async fn create_job(&self, name: &str, queue: &str, cron_expression: &str, extra: Option<Value>) -> Result<Value, JobcelisError> {
        let mut body = json!({"name": name, "queue": queue, "cron_expression": cron_expression});
        if let Some(e) = extra {
            if let Value::Object(map) = e {
                for (k, v) in map { body[k] = v; }
            }
        }
        self.post("/api/v1/jobs", body).await
    }

    /// List scheduled jobs.
    pub async fn list_jobs(&self, limit: u32, cursor: Option<&str>) -> Result<Value, JobcelisError> {
        let mut params: Vec<(&str, String)> = vec![("limit", limit.to_string())];
        if let Some(c) = cursor { params.push(("cursor", c.to_string())); }
        self.get("/api/v1/jobs", &params).await
    }

    /// Get job details.
    pub async fn get_job(&self, job_id: &str) -> Result<Value, JobcelisError> {
        self.get(&format!("/api/v1/jobs/{job_id}"), &[]).await
    }

    /// Update a scheduled job.
    pub async fn update_job(&self, job_id: &str, data: Value) -> Result<Value, JobcelisError> {
        self.patch(&format!("/api/v1/jobs/{job_id}"), data).await
    }

    /// Delete a scheduled job.
    pub async fn delete_job(&self, job_id: &str) -> Result<(), JobcelisError> {
        self.do_delete(&format!("/api/v1/jobs/{job_id}")).await
    }

    /// List runs for a scheduled job.
    pub async fn list_job_runs(&self, job_id: &str, limit: u32) -> Result<Value, JobcelisError> {
        self.get(&format!("/api/v1/jobs/{job_id}/runs"), &[("limit", limit.to_string())]).await
    }

    /// Preview next occurrences for a cron expression.
    pub async fn cron_preview(&self, expression: &str, count: u32) -> Result<Value, JobcelisError> {
        self.get("/api/v1/jobs/cron-preview", &[("expression", expression.to_string()), ("count", count.to_string())]).await
    }

    // -------------------------------------------------------------------------
    // Pipelines
    // -------------------------------------------------------------------------

    /// Create an event pipeline.
    pub async fn create_pipeline(&self, name: &str, topics: Vec<&str>, steps: Vec<Value>) -> Result<Value, JobcelisError> {
        self.post("/api/v1/pipelines", json!({"name": name, "topics": topics, "steps": steps})).await
    }

    /// List pipelines.
    pub async fn list_pipelines(&self, limit: u32, cursor: Option<&str>) -> Result<Value, JobcelisError> {
        let mut params: Vec<(&str, String)> = vec![("limit", limit.to_string())];
        if let Some(c) = cursor { params.push(("cursor", c.to_string())); }
        self.get("/api/v1/pipelines", &params).await
    }

    /// Get pipeline details.
    pub async fn get_pipeline(&self, pipeline_id: &str) -> Result<Value, JobcelisError> {
        self.get(&format!("/api/v1/pipelines/{pipeline_id}"), &[]).await
    }

    /// Update a pipeline.
    pub async fn update_pipeline(&self, pipeline_id: &str, data: Value) -> Result<Value, JobcelisError> {
        self.patch(&format!("/api/v1/pipelines/{pipeline_id}"), data).await
    }

    /// Delete a pipeline.
    pub async fn delete_pipeline(&self, pipeline_id: &str) -> Result<(), JobcelisError> {
        self.do_delete(&format!("/api/v1/pipelines/{pipeline_id}")).await
    }

    /// Test a pipeline with a sample payload.
    pub async fn test_pipeline(&self, pipeline_id: &str, payload: Value) -> Result<Value, JobcelisError> {
        self.post(&format!("/api/v1/pipelines/{pipeline_id}/test"), payload).await
    }

    // -------------------------------------------------------------------------
    // Event Schemas
    // -------------------------------------------------------------------------

    /// Create an event schema.
    pub async fn create_event_schema(&self, topic: &str, schema: Value) -> Result<Value, JobcelisError> {
        self.post("/api/v1/event-schemas", json!({"topic": topic, "schema": schema})).await
    }

    /// List event schemas.
    pub async fn list_event_schemas(&self, limit: u32, cursor: Option<&str>) -> Result<Value, JobcelisError> {
        let mut params: Vec<(&str, String)> = vec![("limit", limit.to_string())];
        if let Some(c) = cursor { params.push(("cursor", c.to_string())); }
        self.get("/api/v1/event-schemas", &params).await
    }

    /// Get event schema details.
    pub async fn get_event_schema(&self, schema_id: &str) -> Result<Value, JobcelisError> {
        self.get(&format!("/api/v1/event-schemas/{schema_id}"), &[]).await
    }

    /// Update an event schema.
    pub async fn update_event_schema(&self, schema_id: &str, data: Value) -> Result<Value, JobcelisError> {
        self.patch(&format!("/api/v1/event-schemas/{schema_id}"), data).await
    }

    /// Delete an event schema.
    pub async fn delete_event_schema(&self, schema_id: &str) -> Result<(), JobcelisError> {
        self.do_delete(&format!("/api/v1/event-schemas/{schema_id}")).await
    }

    /// Validate a payload against the schema for a topic.
    pub async fn validate_payload(&self, topic: &str, payload: Value) -> Result<Value, JobcelisError> {
        self.post("/api/v1/event-schemas/validate", json!({"topic": topic, "payload": payload})).await
    }

    // -------------------------------------------------------------------------
    // Sandbox
    // -------------------------------------------------------------------------

    /// List sandbox endpoints.
    pub async fn list_sandbox_endpoints(&self) -> Result<Value, JobcelisError> {
        self.get("/api/v1/sandbox-endpoints", &[]).await
    }

    /// Create a sandbox endpoint.
    pub async fn create_sandbox_endpoint(&self, name: Option<&str>) -> Result<Value, JobcelisError> {
        let body = match name {
            Some(n) => json!({"name": n}),
            None => json!({}),
        };
        self.post("/api/v1/sandbox-endpoints", body).await
    }

    /// Delete a sandbox endpoint.
    pub async fn delete_sandbox_endpoint(&self, endpoint_id: &str) -> Result<(), JobcelisError> {
        self.do_delete(&format!("/api/v1/sandbox-endpoints/{endpoint_id}")).await
    }

    /// List requests received by a sandbox endpoint.
    pub async fn list_sandbox_requests(&self, endpoint_id: &str, limit: u32) -> Result<Value, JobcelisError> {
        self.get(&format!("/api/v1/sandbox-endpoints/{endpoint_id}/requests"), &[("limit", limit.to_string())]).await
    }

    // -------------------------------------------------------------------------
    // Analytics
    // -------------------------------------------------------------------------

    /// Get events per day for the last N days.
    pub async fn events_per_day(&self, days: u32) -> Result<Value, JobcelisError> {
        self.get("/api/v1/analytics/events-per-day", &[("days", days.to_string())]).await
    }

    /// Get deliveries per day for the last N days.
    pub async fn deliveries_per_day(&self, days: u32) -> Result<Value, JobcelisError> {
        self.get("/api/v1/analytics/deliveries-per-day", &[("days", days.to_string())]).await
    }

    /// Get top topics by event count.
    pub async fn top_topics(&self, limit: u32) -> Result<Value, JobcelisError> {
        self.get("/api/v1/analytics/top-topics", &[("limit", limit.to_string())]).await
    }

    /// Get webhook delivery statistics.
    pub async fn webhook_stats(&self) -> Result<Value, JobcelisError> {
        self.get("/api/v1/analytics/webhook-stats", &[]).await
    }

    // -------------------------------------------------------------------------
    // Project (current)
    // -------------------------------------------------------------------------

    /// Get current project details.
    pub async fn get_project(&self) -> Result<Value, JobcelisError> {
        self.get("/api/v1/project", &[]).await
    }

    /// Update current project.
    pub async fn update_project(&self, data: Value) -> Result<Value, JobcelisError> {
        self.patch("/api/v1/project", data).await
    }

    /// List all topics in the current project.
    pub async fn list_topics(&self) -> Result<Value, JobcelisError> {
        self.get("/api/v1/topics", &[]).await
    }

    /// Get the current API token info.
    pub async fn get_token(&self) -> Result<Value, JobcelisError> {
        self.get("/api/v1/token", &[]).await
    }

    /// Regenerate the API token.
    pub async fn regenerate_token(&self) -> Result<Value, JobcelisError> {
        self.post("/api/v1/token/regenerate", json!({})).await
    }

    // -------------------------------------------------------------------------
    // Projects (multi)
    // -------------------------------------------------------------------------

    /// List all projects.
    pub async fn list_projects(&self) -> Result<Value, JobcelisError> {
        self.get("/api/v1/projects", &[]).await
    }

    /// Create a new project.
    pub async fn create_project(&self, name: &str) -> Result<Value, JobcelisError> {
        self.post("/api/v1/projects", json!({"name": name})).await
    }

    /// Get project by ID.
    pub async fn get_project_by_id(&self, project_id: &str) -> Result<Value, JobcelisError> {
        self.get(&format!("/api/v1/projects/{project_id}"), &[]).await
    }

    /// Update a project by ID.
    pub async fn update_project_by_id(&self, project_id: &str, data: Value) -> Result<Value, JobcelisError> {
        self.patch(&format!("/api/v1/projects/{project_id}"), data).await
    }

    /// Delete a project.
    pub async fn delete_project(&self, project_id: &str) -> Result<(), JobcelisError> {
        self.do_delete(&format!("/api/v1/projects/{project_id}")).await
    }

    /// Set a project as the default.
    pub async fn set_default_project(&self, project_id: &str) -> Result<Value, JobcelisError> {
        self.patch(&format!("/api/v1/projects/{project_id}/default"), json!({})).await
    }

    // -------------------------------------------------------------------------
    // Teams
    // -------------------------------------------------------------------------

    /// List members of a project.
    pub async fn list_members(&self, project_id: &str) -> Result<Value, JobcelisError> {
        self.get(&format!("/api/v1/projects/{project_id}/members"), &[]).await
    }

    /// Add a member to a project.
    pub async fn add_member(&self, project_id: &str, email: &str, role: Option<&str>) -> Result<Value, JobcelisError> {
        let r = role.unwrap_or("member");
        self.post(&format!("/api/v1/projects/{project_id}/members"), json!({"email": email, "role": r})).await
    }

    /// Update a member's role.
    pub async fn update_member(&self, project_id: &str, member_id: &str, role: &str) -> Result<Value, JobcelisError> {
        self.patch(&format!("/api/v1/projects/{project_id}/members/{member_id}"), json!({"role": role})).await
    }

    /// Remove a member from a project.
    pub async fn remove_member(&self, project_id: &str, member_id: &str) -> Result<(), JobcelisError> {
        self.do_delete(&format!("/api/v1/projects/{project_id}/members/{member_id}")).await
    }

    // -------------------------------------------------------------------------
    // Invitations
    // -------------------------------------------------------------------------

    /// List pending invitations for the current user.
    pub async fn list_pending_invitations(&self) -> Result<Value, JobcelisError> {
        self.get("/api/v1/invitations/pending", &[]).await
    }

    /// Accept an invitation.
    pub async fn accept_invitation(&self, invitation_id: &str) -> Result<Value, JobcelisError> {
        self.post(&format!("/api/v1/invitations/{invitation_id}/accept"), json!({})).await
    }

    /// Reject an invitation.
    pub async fn reject_invitation(&self, invitation_id: &str) -> Result<Value, JobcelisError> {
        self.post(&format!("/api/v1/invitations/{invitation_id}/reject"), json!({})).await
    }

    // -------------------------------------------------------------------------
    // Audit
    // -------------------------------------------------------------------------

    /// List audit log entries.
    pub async fn list_audit_logs(&self, limit: u32, cursor: Option<&str>) -> Result<Value, JobcelisError> {
        let mut params: Vec<(&str, String)> = vec![("limit", limit.to_string())];
        if let Some(c) = cursor { params.push(("cursor", c.to_string())); }
        self.get("/api/v1/audit-log", &params).await
    }

    // -------------------------------------------------------------------------
    // Export
    // -------------------------------------------------------------------------

    /// Export events as CSV or JSON. Returns raw string.
    pub async fn export_events(&self, format: &str) -> Result<String, JobcelisError> {
        self.get_raw("/api/v1/export/events", &[("format", format.to_string())]).await
    }

    /// Export deliveries as CSV or JSON. Returns raw string.
    pub async fn export_deliveries(&self, format: &str) -> Result<String, JobcelisError> {
        self.get_raw("/api/v1/export/deliveries", &[("format", format.to_string())]).await
    }

    /// Export jobs as CSV or JSON. Returns raw string.
    pub async fn export_jobs(&self, format: &str) -> Result<String, JobcelisError> {
        self.get_raw("/api/v1/export/jobs", &[("format", format.to_string())]).await
    }

    /// Export audit log as CSV or JSON. Returns raw string.
    pub async fn export_audit_log(&self, format: &str) -> Result<String, JobcelisError> {
        self.get_raw("/api/v1/export/audit-log", &[("format", format.to_string())]).await
    }

    // -------------------------------------------------------------------------
    // GDPR
    // -------------------------------------------------------------------------

    /// Get current user consent status.
    pub async fn get_consents(&self) -> Result<Value, JobcelisError> {
        self.get("/api/v1/me/consents", &[]).await
    }

    /// Accept consent for a specific purpose.
    pub async fn accept_consent(&self, purpose: &str) -> Result<Value, JobcelisError> {
        self.post(&format!("/api/v1/me/consents/{purpose}/accept"), json!({})).await
    }

    /// Export all personal data (GDPR data portability).
    pub async fn export_my_data(&self) -> Result<Value, JobcelisError> {
        self.get("/api/v1/me/data", &[]).await
    }

    /// Request restriction of data processing.
    pub async fn restrict_processing(&self) -> Result<Value, JobcelisError> {
        self.post("/api/v1/me/restrict", json!({})).await
    }

    /// Lift restriction on data processing.
    pub async fn lift_restriction(&self) -> Result<(), JobcelisError> {
        self.do_delete("/api/v1/me/restrict").await
    }

    /// Object to data processing.
    pub async fn object_to_processing(&self) -> Result<Value, JobcelisError> {
        self.post("/api/v1/me/object", json!({})).await
    }

    /// Withdraw objection to data processing.
    pub async fn restore_consent(&self) -> Result<(), JobcelisError> {
        self.do_delete("/api/v1/me/object").await
    }

    // -------------------------------------------------------------------------
    // Embed Tokens
    // -------------------------------------------------------------------------

    /// List embed tokens.
    pub async fn list_embed_tokens(&self) -> Result<Value, JobcelisError> {
        self.get("/api/v1/embed/tokens", &[]).await
    }

    /// Create an embed token.
    pub async fn create_embed_token(&self, config: Value) -> Result<Value, JobcelisError> {
        self.post("/api/v1/embed/tokens", config).await
    }

    /// Revoke an embed token.
    pub async fn revoke_embed_token(&self, id: &str) -> Result<(), JobcelisError> {
        self.do_delete(&format!("/api/v1/embed/tokens/{id}")).await
    }

    // -------------------------------------------------------------------------
    // Notification Channels
    // -------------------------------------------------------------------------

    /// Get the notification channel configuration.
    pub async fn get_notification_channel(&self) -> Result<Value, JobcelisError> {
        self.get("/api/v1/notification-channels", &[]).await
    }

    /// Create or update the notification channel configuration.
    pub async fn upsert_notification_channel(&self, config: Value) -> Result<Value, JobcelisError> {
        self.put("/api/v1/notification-channels", config).await
    }

    /// Delete the notification channel configuration.
    pub async fn delete_notification_channel(&self) -> Result<(), JobcelisError> {
        self.do_delete("/api/v1/notification-channels").await
    }

    /// Send a test notification to the configured channel.
    pub async fn test_notification_channel(&self) -> Result<Value, JobcelisError> {
        self.post("/api/v1/notification-channels/test", json!({})).await
    }

    // -------------------------------------------------------------------------
    // Health
    // -------------------------------------------------------------------------

    /// Check API health.
    pub async fn health(&self) -> Result<Value, JobcelisError> {
        self.get("/health", &[]).await
    }

    /// Get platform status.
    pub async fn status(&self) -> Result<Value, JobcelisError> {
        self.get("/status", &[]).await
    }

    // =========================================================================
    // Private HTTP helpers
    // =========================================================================

    async fn get(&self, path: &str, params: &[(&str, String)]) -> Result<Value, JobcelisError> {
        self.request(Method::GET, path, params, None).await
    }

    async fn post(&self, path: &str, body: Value) -> Result<Value, JobcelisError> {
        self.request(Method::POST, path, &[], Some(body)).await
    }

    async fn put(&self, path: &str, body: Value) -> Result<Value, JobcelisError> {
        self.request(Method::PUT, path, &[], Some(body)).await
    }

    async fn patch(&self, path: &str, body: Value) -> Result<Value, JobcelisError> {
        self.request(Method::PATCH, path, &[], Some(body)).await
    }

    async fn do_delete(&self, path: &str) -> Result<(), JobcelisError> {
        self.request(Method::DELETE, path, &[], None).await?;
        Ok(())
    }

    async fn get_raw(&self, path: &str, params: &[(&str, String)]) -> Result<String, JobcelisError> {
        let url = format!("{}{}", self.base_url, path);
        let mut req = self.http.request(Method::GET, &url)
            .header("x-api-key", &self.api_key)
            .query(params);
        if let Some(ref token) = self.auth_token {
            req = req.header("authorization", format!("Bearer {token}"));
        }
        let resp = req.send().await?;
        let status = resp.status().as_u16();
        let body = resp.text().await?;
        if status >= 400 {
            let detail = serde_json::from_str(&body).unwrap_or(json!(body));
            return Err(JobcelisError::Api { status, detail });
        }
        Ok(body)
    }

    async fn public_post(&self, path: &str, body: Value) -> Result<Value, JobcelisError> {
        let url = format!("{}{}", self.base_url, path);
        let resp = self.http.post(&url)
            .header("content-type", "application/json")
            .json(&body)
            .send()
            .await?;
        self.handle_response(resp).await
    }

    async fn request(&self, method: Method, path: &str, params: &[(&str, String)], body: Option<Value>) -> Result<Value, JobcelisError> {
        let url = format!("{}{}", self.base_url, path);
        let mut req = self.http.request(method, &url)
            .header("content-type", "application/json")
            .header("accept", "application/json")
            .header("x-api-key", &self.api_key);
        if let Some(ref token) = self.auth_token {
            req = req.header("authorization", format!("Bearer {token}"));
        }
        if !params.is_empty() {
            req = req.query(params);
        }
        if let Some(b) = body {
            req = req.json(&b);
        }
        let resp = req.send().await?;
        self.handle_response(resp).await
    }

    async fn handle_response(&self, resp: Response) -> Result<Value, JobcelisError> {
        let status = resp.status().as_u16();
        if status == 204 {
            return Ok(json!(null));
        }
        let body = resp.text().await?;
        if status >= 400 {
            let detail = serde_json::from_str(&body).unwrap_or(json!(body));
            return Err(JobcelisError::Api { status, detail });
        }
        let parsed: Value = serde_json::from_str(&body)?;
        Ok(parsed)
    }
}
