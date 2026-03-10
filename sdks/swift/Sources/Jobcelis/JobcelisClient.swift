import Foundation

/// Client for the Jobcelis Event Infrastructure Platform API.
///
/// All API calls go to `https://jobcelis.com` by default.
///
/// ```swift
/// let client = JobcelisClient(apiKey: "your_api_key")
/// let event = try await client.sendEvent(topic: "order.created", payload: ["order_id": "123"])
/// ```
public class JobcelisClient {
    private let apiKey: String
    private let baseURL: String
    private let session: URLSession
    private var authToken: String?

    /// Create a new Jobcelis client.
    ///
    /// - Parameters:
    ///   - apiKey: Your Jobcelis API key.
    ///   - baseURL: Base URL of the Jobcelis API (default: `https://jobcelis.com`).
    ///   - session: URLSession to use (default: `.shared`).
    public init(apiKey: String, baseURL: String = "https://jobcelis.com", session: URLSession = .shared) {
        self.apiKey = apiKey
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.session = session
    }

    /// Set JWT bearer token for authenticated requests.
    public func setAuthToken(_ token: String) {
        authToken = token
    }

    // MARK: - Auth

    /// Register a new account. Does not use API key auth.
    public func register(email: String, password: String, name: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["email": email, "password": password]
        if let name = name { body["name"] = name }
        return try await publicPost("/api/v1/auth/register", body: body)
    }

    /// Log in and receive JWT + refresh token.
    public func login(email: String, password: String) async throws -> [String: Any] {
        try await publicPost("/api/v1/auth/login", body: ["email": email, "password": password])
    }

    /// Refresh an expired JWT.
    public func refreshToken(_ refreshToken: String) async throws -> [String: Any] {
        try await publicPost("/api/v1/auth/refresh", body: ["refresh_token": refreshToken])
    }

    /// Verify MFA code.
    public func verifyMfa(token: String, code: String) async throws -> [String: Any] {
        try await post("/api/v1/auth/mfa/verify", body: ["token": token, "code": code])
    }

    // MARK: - Events

    /// Send a single event.
    public func sendEvent(topic: String, payload: [String: Any]) async throws -> [String: Any] {
        try await post("/api/v1/events", body: ["topic": topic, "payload": payload])
    }

    /// Send up to 1000 events in a batch.
    public func sendEvents(_ events: [[String: Any]]) async throws -> [String: Any] {
        try await post("/api/v1/events/batch", body: ["events": events])
    }

    /// Get event details.
    public func getEvent(_ eventId: String) async throws -> [String: Any] {
        try await get("/api/v1/events/\(eventId)")
    }

    /// List events with cursor pagination.
    public func listEvents(limit: Int = 50, cursor: String? = nil) async throws -> [String: Any] {
        try await get("/api/v1/events", params: ["limit": "\(limit)", "cursor": cursor])
    }

    /// Delete an event.
    public func deleteEvent(_ eventId: String) async throws {
        try await doDelete("/api/v1/events/\(eventId)")
    }

    // MARK: - Simulate

    /// Simulate sending an event (dry run).
    public func simulateEvent(topic: String, payload: [String: Any]) async throws -> [String: Any] {
        try await post("/api/v1/simulate", body: ["topic": topic, "payload": payload])
    }

    // MARK: - Webhooks

    /// Create a webhook.
    ///
    /// - Parameters:
    ///   - url: The webhook endpoint URL.
    ///   - rateLimit: Optional rate limit with `max_per_second` and/or `max_per_minute`.
    ///   - extra: Additional fields to include in the request body.
    public func createWebhook(url: String, rateLimit: [String: Any]? = nil, extra: [String: Any] = [:]) async throws -> [String: Any] {
        var body: [String: Any] = ["url": url]
        if let rateLimit = rateLimit { body["rate_limit"] = rateLimit }
        for (k, v) in extra { body[k] = v }
        return try await post("/api/v1/webhooks", body: body)
    }

    /// Get webhook details.
    public func getWebhook(_ webhookId: String) async throws -> [String: Any] {
        try await get("/api/v1/webhooks/\(webhookId)")
    }

    /// List webhooks.
    public func listWebhooks(limit: Int = 50, cursor: String? = nil) async throws -> [String: Any] {
        try await get("/api/v1/webhooks", params: ["limit": "\(limit)", "cursor": cursor])
    }

    /// Update a webhook.
    ///
    /// - Parameters:
    ///   - webhookId: The webhook ID.
    ///   - data: Fields to update.
    ///   - rateLimit: Optional rate limit with `max_per_second` and/or `max_per_minute`.
    public func updateWebhook(_ webhookId: String, data: [String: Any], rateLimit: [String: Any]? = nil) async throws -> [String: Any] {
        var body = data
        if let rateLimit = rateLimit { body["rate_limit"] = rateLimit }
        return try await patch("/api/v1/webhooks/\(webhookId)", body: body)
    }

    /// Delete a webhook.
    public func deleteWebhook(_ webhookId: String) async throws {
        try await doDelete("/api/v1/webhooks/\(webhookId)")
    }

    /// Get health status for a webhook.
    public func webhookHealth(_ webhookId: String) async throws -> [String: Any] {
        try await get("/api/v1/webhooks/\(webhookId)/health")
    }

    /// List available webhook templates.
    public func webhookTemplates() async throws -> [String: Any] {
        try await get("/api/v1/webhooks/templates")
    }

    // MARK: - Deliveries

    /// List deliveries.
    public func listDeliveries(limit: Int = 50, cursor: String? = nil, status: String? = nil) async throws -> [String: Any] {
        try await get("/api/v1/deliveries", params: ["limit": "\(limit)", "cursor": cursor, "status": status])
    }

    /// Retry a failed delivery.
    public func retryDelivery(_ deliveryId: String) async throws -> [String: Any] {
        try await post("/api/v1/deliveries/\(deliveryId)/retry", body: [:])
    }

    // MARK: - Dead Letters

    /// List dead letters.
    public func listDeadLetters(limit: Int = 50, cursor: String? = nil) async throws -> [String: Any] {
        try await get("/api/v1/dead-letters", params: ["limit": "\(limit)", "cursor": cursor])
    }

    /// Get dead letter details.
    public func getDeadLetter(_ deadLetterId: String) async throws -> [String: Any] {
        try await get("/api/v1/dead-letters/\(deadLetterId)")
    }

    /// Retry a dead letter.
    public func retryDeadLetter(_ deadLetterId: String) async throws -> [String: Any] {
        try await post("/api/v1/dead-letters/\(deadLetterId)/retry", body: [:])
    }

    /// Mark a dead letter as resolved.
    public func resolveDeadLetter(_ deadLetterId: String) async throws -> [String: Any] {
        try await patch("/api/v1/dead-letters/\(deadLetterId)/resolve", body: [:])
    }

    // MARK: - Replays

    /// Start an event replay.
    public func createReplay(topic: String, fromDate: String, toDate: String, webhookId: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["topic": topic, "from_date": fromDate, "to_date": toDate]
        if let wh = webhookId { body["webhook_id"] = wh }
        return try await post("/api/v1/replays", body: body)
    }

    /// List replays.
    public func listReplays(limit: Int = 50, cursor: String? = nil) async throws -> [String: Any] {
        try await get("/api/v1/replays", params: ["limit": "\(limit)", "cursor": cursor])
    }

    /// Get replay details.
    public func getReplay(_ replayId: String) async throws -> [String: Any] {
        try await get("/api/v1/replays/\(replayId)")
    }

    /// Cancel a replay.
    public func cancelReplay(_ replayId: String) async throws {
        try await doDelete("/api/v1/replays/\(replayId)")
    }

    // MARK: - Jobs

    /// Create a scheduled job.
    public func createJob(name: String, queue: String, cronExpression: String, extra: [String: Any] = [:]) async throws -> [String: Any] {
        var body: [String: Any] = ["name": name, "queue": queue, "cron_expression": cronExpression]
        for (k, v) in extra { body[k] = v }
        return try await post("/api/v1/jobs", body: body)
    }

    /// List scheduled jobs.
    public func listJobs(limit: Int = 50, cursor: String? = nil) async throws -> [String: Any] {
        try await get("/api/v1/jobs", params: ["limit": "\(limit)", "cursor": cursor])
    }

    /// Get job details.
    public func getJob(_ jobId: String) async throws -> [String: Any] {
        try await get("/api/v1/jobs/\(jobId)")
    }

    /// Update a scheduled job.
    public func updateJob(_ jobId: String, data: [String: Any]) async throws -> [String: Any] {
        try await patch("/api/v1/jobs/\(jobId)", body: data)
    }

    /// Delete a scheduled job.
    public func deleteJob(_ jobId: String) async throws {
        try await doDelete("/api/v1/jobs/\(jobId)")
    }

    /// List runs for a scheduled job.
    public func listJobRuns(_ jobId: String, limit: Int = 50) async throws -> [String: Any] {
        try await get("/api/v1/jobs/\(jobId)/runs", params: ["limit": "\(limit)"])
    }

    /// Preview next occurrences for a cron expression.
    public func cronPreview(_ expression: String, count: Int = 5) async throws -> [String: Any] {
        try await get("/api/v1/jobs/cron-preview", params: ["expression": expression, "count": "\(count)"])
    }

    // MARK: - Pipelines

    /// Create an event pipeline.
    public func createPipeline(name: String, topics: [String], steps: [[String: Any]]) async throws -> [String: Any] {
        try await post("/api/v1/pipelines", body: ["name": name, "topics": topics, "steps": steps])
    }

    /// List pipelines.
    public func listPipelines(limit: Int = 50, cursor: String? = nil) async throws -> [String: Any] {
        try await get("/api/v1/pipelines", params: ["limit": "\(limit)", "cursor": cursor])
    }

    /// Get pipeline details.
    public func getPipeline(_ pipelineId: String) async throws -> [String: Any] {
        try await get("/api/v1/pipelines/\(pipelineId)")
    }

    /// Update a pipeline.
    public func updatePipeline(_ pipelineId: String, data: [String: Any]) async throws -> [String: Any] {
        try await patch("/api/v1/pipelines/\(pipelineId)", body: data)
    }

    /// Delete a pipeline.
    public func deletePipeline(_ pipelineId: String) async throws {
        try await doDelete("/api/v1/pipelines/\(pipelineId)")
    }

    /// Test a pipeline with a sample payload.
    public func testPipeline(_ pipelineId: String, payload: [String: Any]) async throws -> [String: Any] {
        try await post("/api/v1/pipelines/\(pipelineId)/test", body: payload)
    }

    // MARK: - Event Schemas

    /// Create an event schema.
    public func createEventSchema(topic: String, schema: [String: Any]) async throws -> [String: Any] {
        try await post("/api/v1/event-schemas", body: ["topic": topic, "schema": schema])
    }

    /// List event schemas.
    public func listEventSchemas(limit: Int = 50, cursor: String? = nil) async throws -> [String: Any] {
        try await get("/api/v1/event-schemas", params: ["limit": "\(limit)", "cursor": cursor])
    }

    /// Get event schema details.
    public func getEventSchema(_ schemaId: String) async throws -> [String: Any] {
        try await get("/api/v1/event-schemas/\(schemaId)")
    }

    /// Update an event schema.
    public func updateEventSchema(_ schemaId: String, data: [String: Any]) async throws -> [String: Any] {
        try await patch("/api/v1/event-schemas/\(schemaId)", body: data)
    }

    /// Delete an event schema.
    public func deleteEventSchema(_ schemaId: String) async throws {
        try await doDelete("/api/v1/event-schemas/\(schemaId)")
    }

    /// Validate a payload against the schema for a topic.
    public func validatePayload(topic: String, payload: [String: Any]) async throws -> [String: Any] {
        try await post("/api/v1/event-schemas/validate", body: ["topic": topic, "payload": payload])
    }

    // MARK: - Sandbox

    /// List sandbox endpoints.
    public func listSandboxEndpoints() async throws -> [String: Any] {
        try await get("/api/v1/sandbox-endpoints")
    }

    /// Create a sandbox endpoint.
    public func createSandboxEndpoint(name: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = [:]
        if let n = name { body["name"] = n }
        return try await post("/api/v1/sandbox-endpoints", body: body)
    }

    /// Delete a sandbox endpoint.
    public func deleteSandboxEndpoint(_ endpointId: String) async throws {
        try await doDelete("/api/v1/sandbox-endpoints/\(endpointId)")
    }

    /// List requests received by a sandbox endpoint.
    public func listSandboxRequests(_ endpointId: String, limit: Int = 50) async throws -> [String: Any] {
        try await get("/api/v1/sandbox-endpoints/\(endpointId)/requests", params: ["limit": "\(limit)"])
    }

    // MARK: - Analytics

    /// Get events per day for the last N days.
    public func eventsPerDay(days: Int = 7) async throws -> [String: Any] {
        try await get("/api/v1/analytics/events-per-day", params: ["days": "\(days)"])
    }

    /// Get deliveries per day for the last N days.
    public func deliveriesPerDay(days: Int = 7) async throws -> [String: Any] {
        try await get("/api/v1/analytics/deliveries-per-day", params: ["days": "\(days)"])
    }

    /// Get top topics by event count.
    public func topTopics(limit: Int = 10) async throws -> [String: Any] {
        try await get("/api/v1/analytics/top-topics", params: ["limit": "\(limit)"])
    }

    /// Get webhook delivery statistics.
    public func webhookStats() async throws -> [String: Any] {
        try await get("/api/v1/analytics/webhook-stats")
    }

    // MARK: - Project (current)

    /// Get current project details.
    public func getProject() async throws -> [String: Any] {
        try await get("/api/v1/project")
    }

    /// Update current project.
    public func updateProject(_ data: [String: Any]) async throws -> [String: Any] {
        try await patch("/api/v1/project", body: data)
    }

    /// List all topics in the current project.
    public func listTopics() async throws -> [String: Any] {
        try await get("/api/v1/topics")
    }

    /// Get the current API token info.
    public func getToken() async throws -> [String: Any] {
        try await get("/api/v1/token")
    }

    /// Regenerate the API token.
    public func regenerateToken() async throws -> [String: Any] {
        try await post("/api/v1/token/regenerate", body: [:])
    }

    // MARK: - Projects (multi)

    /// List all projects.
    public func listProjects() async throws -> [String: Any] {
        try await get("/api/v1/projects")
    }

    /// Create a new project.
    public func createProject(_ name: String) async throws -> [String: Any] {
        try await post("/api/v1/projects", body: ["name": name])
    }

    /// Get project by ID.
    public func getProjectById(_ projectId: String) async throws -> [String: Any] {
        try await get("/api/v1/projects/\(projectId)")
    }

    /// Update a project by ID.
    public func updateProjectById(_ projectId: String, data: [String: Any]) async throws -> [String: Any] {
        try await patch("/api/v1/projects/\(projectId)", body: data)
    }

    /// Delete a project.
    public func deleteProject(_ projectId: String) async throws {
        try await doDelete("/api/v1/projects/\(projectId)")
    }

    /// Set a project as the default.
    public func setDefaultProject(_ projectId: String) async throws -> [String: Any] {
        try await patch("/api/v1/projects/\(projectId)/default", body: [:])
    }

    // MARK: - Teams

    /// List members of a project.
    public func listMembers(_ projectId: String) async throws -> [String: Any] {
        try await get("/api/v1/projects/\(projectId)/members")
    }

    /// Add a member to a project.
    public func addMember(_ projectId: String, email: String, role: String = "member") async throws -> [String: Any] {
        try await post("/api/v1/projects/\(projectId)/members", body: ["email": email, "role": role])
    }

    /// Update a member's role.
    public func updateMember(_ projectId: String, memberId: String, role: String) async throws -> [String: Any] {
        try await patch("/api/v1/projects/\(projectId)/members/\(memberId)", body: ["role": role])
    }

    /// Remove a member from a project.
    public func removeMember(_ projectId: String, memberId: String) async throws {
        try await doDelete("/api/v1/projects/\(projectId)/members/\(memberId)")
    }

    // MARK: - Invitations

    /// List pending invitations for the current user.
    public func listPendingInvitations() async throws -> [String: Any] {
        try await get("/api/v1/invitations/pending")
    }

    /// Accept an invitation.
    public func acceptInvitation(_ invitationId: String) async throws -> [String: Any] {
        try await post("/api/v1/invitations/\(invitationId)/accept", body: [:])
    }

    /// Reject an invitation.
    public func rejectInvitation(_ invitationId: String) async throws -> [String: Any] {
        try await post("/api/v1/invitations/\(invitationId)/reject", body: [:])
    }

    // MARK: - Audit

    /// List audit log entries.
    public func listAuditLogs(limit: Int = 50, cursor: String? = nil) async throws -> [String: Any] {
        try await get("/api/v1/audit-log", params: ["limit": "\(limit)", "cursor": cursor])
    }

    // MARK: - Embed Tokens

    /// List embed tokens.
    public func listEmbedTokens() async throws -> [String: Any] {
        try await get("/api/v1/embed/tokens")
    }

    /// Create an embed token.
    public func createEmbedToken(config: [String: Any]) async throws -> [String: Any] {
        try await post("/api/v1/embed/tokens", body: config)
    }

    /// Revoke an embed token.
    public func revokeEmbedToken(id: String) async throws {
        try await doDelete("/api/v1/embed/tokens/\(id)")
    }

    // MARK: - Notification Channels

    /// Get the notification channel configuration.
    public func getNotificationChannel() async throws -> [String: Any] {
        try await get("/api/v1/notification-channels")
    }

    /// Create or update the notification channel configuration.
    public func upsertNotificationChannel(config: [String: Any]) async throws -> [String: Any] {
        try await request("PUT", path: "/api/v1/notification-channels", body: config)
    }

    /// Delete the notification channel configuration.
    public func deleteNotificationChannel() async throws {
        try await doDelete("/api/v1/notification-channels")
    }

    /// Test the notification channel configuration.
    public func testNotificationChannel() async throws -> [String: Any] {
        try await post("/api/v1/notification-channels/test", body: [:])
    }

    // MARK: - Export

    /// Export events as CSV or JSON. Returns raw string.
    public func exportEvents(format: String = "csv") async throws -> String {
        try await getRaw("/api/v1/export/events", params: ["format": format])
    }

    /// Export deliveries as CSV or JSON. Returns raw string.
    public func exportDeliveries(format: String = "csv") async throws -> String {
        try await getRaw("/api/v1/export/deliveries", params: ["format": format])
    }

    /// Export jobs as CSV or JSON. Returns raw string.
    public func exportJobs(format: String = "csv") async throws -> String {
        try await getRaw("/api/v1/export/jobs", params: ["format": format])
    }

    /// Export audit log as CSV or JSON. Returns raw string.
    public func exportAuditLog(format: String = "csv") async throws -> String {
        try await getRaw("/api/v1/export/audit-log", params: ["format": format])
    }

    // MARK: - GDPR

    /// Get current user consent status.
    public func getConsents() async throws -> [String: Any] {
        try await get("/api/v1/me/consents")
    }

    /// Accept consent for a specific purpose.
    public func acceptConsent(_ purpose: String) async throws -> [String: Any] {
        try await post("/api/v1/me/consents/\(purpose)/accept", body: [:])
    }

    /// Export all personal data (GDPR data portability).
    public func exportMyData() async throws -> [String: Any] {
        try await get("/api/v1/me/data")
    }

    /// Request restriction of data processing.
    public func restrictProcessing() async throws -> [String: Any] {
        try await post("/api/v1/me/restrict", body: [:])
    }

    /// Lift restriction on data processing.
    public func liftRestriction() async throws {
        try await doDelete("/api/v1/me/restrict")
    }

    /// Object to data processing.
    public func objectToProcessing() async throws -> [String: Any] {
        try await post("/api/v1/me/object", body: [:])
    }

    /// Withdraw objection to data processing.
    public func restoreConsent() async throws {
        try await doDelete("/api/v1/me/object")
    }

    // MARK: - Health

    /// Check API health.
    public func health() async throws -> [String: Any] {
        try await get("/health")
    }

    /// Get platform status.
    public func status() async throws -> [String: Any] {
        try await get("/status")
    }

    // MARK: - Private HTTP helpers

    private func get(_ path: String, params: [String: String?] = [:]) async throws -> [String: Any] {
        try await request("GET", path: path, params: params)
    }

    private func post(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        try await request("POST", path: path, body: body)
    }

    private func patch(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        try await request("PATCH", path: path, body: body)
    }

    private func doDelete(_ path: String) async throws {
        _ = try await request("DELETE", path: path)
    }

    private func getRaw(_ path: String, params: [String: String?] = [:]) async throws -> String {
        let url = buildURL(path, params: params)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode >= 400 {
            let detail = try? JSONSerialization.jsonObject(with: data)
            throw JobcelisError(statusCode: statusCode, detail: detail)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    private func publicPost(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        return try handleResponse(data: data, response: response)
    }

    @discardableResult
    private func request(_ method: String, path: String, params: [String: String?] = [:], body: [String: Any]? = nil) async throws -> [String: Any] {
        let url = buildURL(path, params: params)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body, ["POST", "PATCH", "PUT"].contains(method) {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        return try handleResponse(data: data, response: response)
    }

    private func handleResponse(data: Data, response: URLResponse) throws -> [String: Any] {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode == 204 { return [:] }

        if statusCode >= 400 {
            let detail = try? JSONSerialization.jsonObject(with: data)
            throw JobcelisError(statusCode: statusCode, detail: detail)
        }

        let json = try JSONSerialization.jsonObject(with: data)
        return (json as? [String: Any]) ?? [:]
    }

    private func buildURL(_ path: String, params: [String: String?]) -> URL {
        var components = URLComponents(string: "\(baseURL)\(path)")!
        let filtered = params.compactMapValues { $0 }
        if !filtered.isEmpty {
            components.queryItems = filtered.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url!
    }
}
