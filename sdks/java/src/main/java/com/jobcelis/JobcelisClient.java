package com.jobcelis;

import com.google.gson.Gson;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import java.io.IOException;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Scanner;

/**
 * Client for the Jobcelis Event Infrastructure Platform API.
 *
 * <p>All API calls go to {@code https://jobcelis.com} by default.</p>
 *
 * <pre>{@code
 * JobcelisClient client = new JobcelisClient("your_api_key");
 * JsonObject event = client.sendEvent("order.created", Map.of("order_id", "123"));
 * }</pre>
 */
public class JobcelisClient {
    private static final String DEFAULT_BASE_URL = "https://jobcelis.com";
    private static final Gson GSON = new Gson();

    private final String apiKey;
    private final String baseURL;
    private String authToken;

    /**
     * Create a new client with the default base URL.
     *
     * @param apiKey Your Jobcelis API key.
     */
    public JobcelisClient(String apiKey) {
        this(apiKey, DEFAULT_BASE_URL);
    }

    /**
     * Create a new client with a custom base URL.
     *
     * @param apiKey  Your Jobcelis API key.
     * @param baseURL Base URL of the Jobcelis API.
     */
    public JobcelisClient(String apiKey, String baseURL) {
        this.apiKey = apiKey;
        this.baseURL = baseURL.endsWith("/") ? baseURL.substring(0, baseURL.length() - 1) : baseURL;
    }

    /** Set JWT bearer token for authenticated requests. */
    public void setAuthToken(String token) {
        this.authToken = token;
    }

    // ── Auth ──────────────────────────────────────────────────────────────

    /** Register a new account. Does not use API key auth. */
    public JsonObject register(String email, String password, String name) throws JobcelisException, IOException {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("email", email);
        body.put("password", password);
        if (name != null) body.put("name", name);
        return publicPost("/api/v1/auth/register", body);
    }

    /** Log in and receive JWT + refresh token. */
    public JsonObject login(String email, String password) throws JobcelisException, IOException {
        return publicPost("/api/v1/auth/login", Map.of("email", email, "password", password));
    }

    /** Refresh an expired JWT. */
    public JsonObject refreshToken(String refreshToken) throws JobcelisException, IOException {
        return publicPost("/api/v1/auth/refresh", Map.of("refresh_token", refreshToken));
    }

    /** Verify MFA code. */
    public JsonObject verifyMfa(String token, String code) throws JobcelisException, IOException {
        return post("/api/v1/auth/mfa/verify", Map.of("token", token, "code", code));
    }

    // ── Events ────────────────────────────────────────────────────────────

    /** Send a single event. */
    public JsonObject sendEvent(String topic, Map<String, Object> payload) throws JobcelisException, IOException {
        return post("/api/v1/events", Map.of("topic", topic, "payload", payload));
    }

    /** Send up to 1000 events in a batch. */
    public JsonObject sendEvents(List<Map<String, Object>> events) throws JobcelisException, IOException {
        return post("/api/v1/events/batch", Map.of("events", events));
    }

    /** Get event details. */
    public JsonObject getEvent(String eventId) throws JobcelisException, IOException {
        return get("/api/v1/events/" + eventId);
    }

    /** List events with cursor pagination. */
    public JsonObject listEvents(int limit, String cursor) throws JobcelisException, IOException {
        Map<String, String> params = new LinkedHashMap<>();
        params.put("limit", String.valueOf(limit));
        if (cursor != null) params.put("cursor", cursor);
        return get("/api/v1/events", params);
    }

    /** Delete an event. */
    public void deleteEvent(String eventId) throws JobcelisException, IOException {
        doDelete("/api/v1/events/" + eventId);
    }

    // ── Simulate ──────────────────────────────────────────────────────────

    /** Simulate sending an event (dry run). */
    public JsonObject simulateEvent(String topic, Map<String, Object> payload) throws JobcelisException, IOException {
        return post("/api/v1/simulate", Map.of("topic", topic, "payload", payload));
    }

    // ── Webhooks ──────────────────────────────────────────────────────────

    /** Create a webhook. */
    public JsonObject createWebhook(String url, Map<String, Object> extra) throws JobcelisException, IOException {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("url", url);
        if (extra != null) body.putAll(extra);
        return post("/api/v1/webhooks", body);
    }

    /** Get webhook details. */
    public JsonObject getWebhook(String webhookId) throws JobcelisException, IOException {
        return get("/api/v1/webhooks/" + webhookId);
    }

    /** List webhooks. */
    public JsonObject listWebhooks(int limit, String cursor) throws JobcelisException, IOException {
        Map<String, String> params = new LinkedHashMap<>();
        params.put("limit", String.valueOf(limit));
        if (cursor != null) params.put("cursor", cursor);
        return get("/api/v1/webhooks", params);
    }

    /** Update a webhook. */
    public JsonObject updateWebhook(String webhookId, Map<String, Object> data) throws JobcelisException, IOException {
        return patch("/api/v1/webhooks/" + webhookId, data);
    }

    /** Delete a webhook. */
    public void deleteWebhook(String webhookId) throws JobcelisException, IOException {
        doDelete("/api/v1/webhooks/" + webhookId);
    }

    /** Get health status for a webhook. */
    public JsonObject webhookHealth(String webhookId) throws JobcelisException, IOException {
        return get("/api/v1/webhooks/" + webhookId + "/health");
    }

    /** List available webhook templates. */
    public JsonObject webhookTemplates() throws JobcelisException, IOException {
        return get("/api/v1/webhooks/templates");
    }

    // ── Deliveries ────────────────────────────────────────────────────────

    /** List deliveries. */
    public JsonObject listDeliveries(int limit, String cursor, String status) throws JobcelisException, IOException {
        Map<String, String> params = new LinkedHashMap<>();
        params.put("limit", String.valueOf(limit));
        if (cursor != null) params.put("cursor", cursor);
        if (status != null) params.put("status", status);
        return get("/api/v1/deliveries", params);
    }

    /** Retry a failed delivery. */
    public JsonObject retryDelivery(String deliveryId) throws JobcelisException, IOException {
        return post("/api/v1/deliveries/" + deliveryId + "/retry", Map.of());
    }

    // ── Dead Letters ──────────────────────────────────────────────────────

    /** List dead letters. */
    public JsonObject listDeadLetters(int limit, String cursor) throws JobcelisException, IOException {
        Map<String, String> params = new LinkedHashMap<>();
        params.put("limit", String.valueOf(limit));
        if (cursor != null) params.put("cursor", cursor);
        return get("/api/v1/dead-letters", params);
    }

    /** Get dead letter details. */
    public JsonObject getDeadLetter(String deadLetterId) throws JobcelisException, IOException {
        return get("/api/v1/dead-letters/" + deadLetterId);
    }

    /** Retry a dead letter. */
    public JsonObject retryDeadLetter(String deadLetterId) throws JobcelisException, IOException {
        return post("/api/v1/dead-letters/" + deadLetterId + "/retry", Map.of());
    }

    /** Mark a dead letter as resolved. */
    public JsonObject resolveDeadLetter(String deadLetterId) throws JobcelisException, IOException {
        return patch("/api/v1/dead-letters/" + deadLetterId + "/resolve", Map.of());
    }

    // ── Replays ───────────────────────────────────────────────────────────

    /** Start an event replay. */
    public JsonObject createReplay(String topic, String fromDate, String toDate, String webhookId) throws JobcelisException, IOException {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("topic", topic);
        body.put("from_date", fromDate);
        body.put("to_date", toDate);
        if (webhookId != null) body.put("webhook_id", webhookId);
        return post("/api/v1/replays", body);
    }

    /** List replays. */
    public JsonObject listReplays(int limit, String cursor) throws JobcelisException, IOException {
        Map<String, String> params = new LinkedHashMap<>();
        params.put("limit", String.valueOf(limit));
        if (cursor != null) params.put("cursor", cursor);
        return get("/api/v1/replays", params);
    }

    /** Get replay details. */
    public JsonObject getReplay(String replayId) throws JobcelisException, IOException {
        return get("/api/v1/replays/" + replayId);
    }

    /** Cancel a replay. */
    public void cancelReplay(String replayId) throws JobcelisException, IOException {
        doDelete("/api/v1/replays/" + replayId);
    }

    // ── Jobs ──────────────────────────────────────────────────────────────

    /** Create a scheduled job. */
    public JsonObject createJob(String name, String queue, String cronExpression, Map<String, Object> extra) throws JobcelisException, IOException {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("name", name);
        body.put("queue", queue);
        body.put("cron_expression", cronExpression);
        if (extra != null) body.putAll(extra);
        return post("/api/v1/jobs", body);
    }

    /** List scheduled jobs. */
    public JsonObject listJobs(int limit, String cursor) throws JobcelisException, IOException {
        Map<String, String> params = new LinkedHashMap<>();
        params.put("limit", String.valueOf(limit));
        if (cursor != null) params.put("cursor", cursor);
        return get("/api/v1/jobs", params);
    }

    /** Get job details. */
    public JsonObject getJob(String jobId) throws JobcelisException, IOException {
        return get("/api/v1/jobs/" + jobId);
    }

    /** Update a scheduled job. */
    public JsonObject updateJob(String jobId, Map<String, Object> data) throws JobcelisException, IOException {
        return patch("/api/v1/jobs/" + jobId, data);
    }

    /** Delete a scheduled job. */
    public void deleteJob(String jobId) throws JobcelisException, IOException {
        doDelete("/api/v1/jobs/" + jobId);
    }

    /** List runs for a scheduled job. */
    public JsonObject listJobRuns(String jobId, int limit) throws JobcelisException, IOException {
        return get("/api/v1/jobs/" + jobId + "/runs", Map.of("limit", String.valueOf(limit)));
    }

    /** Preview next occurrences for a cron expression. */
    public JsonObject cronPreview(String expression, int count) throws JobcelisException, IOException {
        return get("/api/v1/jobs/cron-preview", Map.of("expression", expression, "count", String.valueOf(count)));
    }

    // ── Pipelines ─────────────────────────────────────────────────────────

    /** Create an event pipeline. */
    public JsonObject createPipeline(String name, List<String> topics, List<Map<String, Object>> steps) throws JobcelisException, IOException {
        return post("/api/v1/pipelines", Map.of("name", name, "topics", topics, "steps", steps));
    }

    /** List pipelines. */
    public JsonObject listPipelines(int limit, String cursor) throws JobcelisException, IOException {
        Map<String, String> params = new LinkedHashMap<>();
        params.put("limit", String.valueOf(limit));
        if (cursor != null) params.put("cursor", cursor);
        return get("/api/v1/pipelines", params);
    }

    /** Get pipeline details. */
    public JsonObject getPipeline(String pipelineId) throws JobcelisException, IOException {
        return get("/api/v1/pipelines/" + pipelineId);
    }

    /** Update a pipeline. */
    public JsonObject updatePipeline(String pipelineId, Map<String, Object> data) throws JobcelisException, IOException {
        return patch("/api/v1/pipelines/" + pipelineId, data);
    }

    /** Delete a pipeline. */
    public void deletePipeline(String pipelineId) throws JobcelisException, IOException {
        doDelete("/api/v1/pipelines/" + pipelineId);
    }

    /** Test a pipeline with a sample payload. */
    public JsonObject testPipeline(String pipelineId, Map<String, Object> payload) throws JobcelisException, IOException {
        return post("/api/v1/pipelines/" + pipelineId + "/test", payload);
    }

    // ── Event Schemas ─────────────────────────────────────────────────────

    /** Create an event schema. */
    public JsonObject createEventSchema(String topic, Map<String, Object> schema) throws JobcelisException, IOException {
        return post("/api/v1/event-schemas", Map.of("topic", topic, "schema", schema));
    }

    /** List event schemas. */
    public JsonObject listEventSchemas(int limit, String cursor) throws JobcelisException, IOException {
        Map<String, String> params = new LinkedHashMap<>();
        params.put("limit", String.valueOf(limit));
        if (cursor != null) params.put("cursor", cursor);
        return get("/api/v1/event-schemas", params);
    }

    /** Get event schema details. */
    public JsonObject getEventSchema(String schemaId) throws JobcelisException, IOException {
        return get("/api/v1/event-schemas/" + schemaId);
    }

    /** Update an event schema. */
    public JsonObject updateEventSchema(String schemaId, Map<String, Object> data) throws JobcelisException, IOException {
        return patch("/api/v1/event-schemas/" + schemaId, data);
    }

    /** Delete an event schema. */
    public void deleteEventSchema(String schemaId) throws JobcelisException, IOException {
        doDelete("/api/v1/event-schemas/" + schemaId);
    }

    /** Validate a payload against the schema for a topic. */
    public JsonObject validatePayload(String topic, Map<String, Object> payload) throws JobcelisException, IOException {
        return post("/api/v1/event-schemas/validate", Map.of("topic", topic, "payload", payload));
    }

    // ── Sandbox ───────────────────────────────────────────────────────────

    /** List sandbox endpoints. */
    public JsonObject listSandboxEndpoints() throws JobcelisException, IOException {
        return get("/api/v1/sandbox-endpoints");
    }

    /** Create a sandbox endpoint. */
    public JsonObject createSandboxEndpoint(String name) throws JobcelisException, IOException {
        Map<String, Object> body = new LinkedHashMap<>();
        if (name != null) body.put("name", name);
        return post("/api/v1/sandbox-endpoints", body);
    }

    /** Delete a sandbox endpoint. */
    public void deleteSandboxEndpoint(String endpointId) throws JobcelisException, IOException {
        doDelete("/api/v1/sandbox-endpoints/" + endpointId);
    }

    /** List requests received by a sandbox endpoint. */
    public JsonObject listSandboxRequests(String endpointId, int limit) throws JobcelisException, IOException {
        return get("/api/v1/sandbox-endpoints/" + endpointId + "/requests", Map.of("limit", String.valueOf(limit)));
    }

    // ── Analytics ─────────────────────────────────────────────────────────

    /** Get events per day for the last N days. */
    public JsonObject eventsPerDay(int days) throws JobcelisException, IOException {
        return get("/api/v1/analytics/events-per-day", Map.of("days", String.valueOf(days)));
    }

    /** Get deliveries per day for the last N days. */
    public JsonObject deliveriesPerDay(int days) throws JobcelisException, IOException {
        return get("/api/v1/analytics/deliveries-per-day", Map.of("days", String.valueOf(days)));
    }

    /** Get top topics by event count. */
    public JsonObject topTopics(int limit) throws JobcelisException, IOException {
        return get("/api/v1/analytics/top-topics", Map.of("limit", String.valueOf(limit)));
    }

    /** Get webhook delivery statistics. */
    public JsonObject webhookStats() throws JobcelisException, IOException {
        return get("/api/v1/analytics/webhook-stats");
    }

    // ── Project (current) ─────────────────────────────────────────────────

    /** Get current project details. */
    public JsonObject getProject() throws JobcelisException, IOException {
        return get("/api/v1/project");
    }

    /** Update current project. */
    public JsonObject updateProject(Map<String, Object> data) throws JobcelisException, IOException {
        return patch("/api/v1/project", data);
    }

    /** List all topics in the current project. */
    public JsonObject listTopics() throws JobcelisException, IOException {
        return get("/api/v1/topics");
    }

    /** Get the current API token info. */
    public JsonObject getToken() throws JobcelisException, IOException {
        return get("/api/v1/token");
    }

    /** Regenerate the API token. */
    public JsonObject regenerateToken() throws JobcelisException, IOException {
        return post("/api/v1/token/regenerate", Map.of());
    }

    // ── Projects (multi) ──────────────────────────────────────────────────

    /** List all projects. */
    public JsonObject listProjects() throws JobcelisException, IOException {
        return get("/api/v1/projects");
    }

    /** Create a new project. */
    public JsonObject createProject(String name) throws JobcelisException, IOException {
        return post("/api/v1/projects", Map.of("name", name));
    }

    /** Get project by ID. */
    public JsonObject getProjectById(String projectId) throws JobcelisException, IOException {
        return get("/api/v1/projects/" + projectId);
    }

    /** Update a project by ID. */
    public JsonObject updateProjectById(String projectId, Map<String, Object> data) throws JobcelisException, IOException {
        return patch("/api/v1/projects/" + projectId, data);
    }

    /** Delete a project. */
    public void deleteProject(String projectId) throws JobcelisException, IOException {
        doDelete("/api/v1/projects/" + projectId);
    }

    /** Set a project as the default. */
    public JsonObject setDefaultProject(String projectId) throws JobcelisException, IOException {
        return patch("/api/v1/projects/" + projectId + "/default", Map.of());
    }

    // ── Teams ─────────────────────────────────────────────────────────────

    /** List members of a project. */
    public JsonObject listMembers(String projectId) throws JobcelisException, IOException {
        return get("/api/v1/projects/" + projectId + "/members");
    }

    /** Add a member to a project. */
    public JsonObject addMember(String projectId, String email, String role) throws JobcelisException, IOException {
        return post("/api/v1/projects/" + projectId + "/members", Map.of("email", email, "role", role != null ? role : "member"));
    }

    /** Update a member's role. */
    public JsonObject updateMember(String projectId, String memberId, String role) throws JobcelisException, IOException {
        return patch("/api/v1/projects/" + projectId + "/members/" + memberId, Map.of("role", role));
    }

    /** Remove a member from a project. */
    public void removeMember(String projectId, String memberId) throws JobcelisException, IOException {
        doDelete("/api/v1/projects/" + projectId + "/members/" + memberId);
    }

    // ── Invitations ───────────────────────────────────────────────────────

    /** List pending invitations for the current user. */
    public JsonObject listPendingInvitations() throws JobcelisException, IOException {
        return get("/api/v1/invitations/pending");
    }

    /** Accept an invitation. */
    public JsonObject acceptInvitation(String invitationId) throws JobcelisException, IOException {
        return post("/api/v1/invitations/" + invitationId + "/accept", Map.of());
    }

    /** Reject an invitation. */
    public JsonObject rejectInvitation(String invitationId) throws JobcelisException, IOException {
        return post("/api/v1/invitations/" + invitationId + "/reject", Map.of());
    }

    // ── Audit ─────────────────────────────────────────────────────────────

    /** List audit log entries. */
    public JsonObject listAuditLogs(int limit, String cursor) throws JobcelisException, IOException {
        Map<String, String> params = new LinkedHashMap<>();
        params.put("limit", String.valueOf(limit));
        if (cursor != null) params.put("cursor", cursor);
        return get("/api/v1/audit-log", params);
    }

    // ── Export ─────────────────────────────────────────────────────────────

    /** Export events as CSV or JSON. Returns raw string. */
    public String exportEvents(String format) throws JobcelisException, IOException {
        return getRaw("/api/v1/export/events", Map.of("format", format));
    }

    /** Export deliveries as CSV or JSON. Returns raw string. */
    public String exportDeliveries(String format) throws JobcelisException, IOException {
        return getRaw("/api/v1/export/deliveries", Map.of("format", format));
    }

    /** Export jobs as CSV or JSON. Returns raw string. */
    public String exportJobs(String format) throws JobcelisException, IOException {
        return getRaw("/api/v1/export/jobs", Map.of("format", format));
    }

    /** Export audit log as CSV or JSON. Returns raw string. */
    public String exportAuditLog(String format) throws JobcelisException, IOException {
        return getRaw("/api/v1/export/audit-log", Map.of("format", format));
    }

    // ── GDPR ──────────────────────────────────────────────────────────────

    /** Get current user consent status. */
    public JsonObject getConsents() throws JobcelisException, IOException {
        return get("/api/v1/me/consents");
    }

    /** Accept consent for a specific purpose. */
    public JsonObject acceptConsent(String purpose) throws JobcelisException, IOException {
        return post("/api/v1/me/consents/" + purpose + "/accept", Map.of());
    }

    /** Export all personal data (GDPR data portability). */
    public JsonObject exportMyData() throws JobcelisException, IOException {
        return get("/api/v1/me/data");
    }

    /** Request restriction of data processing. */
    public JsonObject restrictProcessing() throws JobcelisException, IOException {
        return post("/api/v1/me/restrict", Map.of());
    }

    /** Lift restriction on data processing. */
    public void liftRestriction() throws JobcelisException, IOException {
        doDelete("/api/v1/me/restrict");
    }

    /** Object to data processing. */
    public JsonObject objectToProcessing() throws JobcelisException, IOException {
        return post("/api/v1/me/object", Map.of());
    }

    /** Withdraw objection to data processing. */
    public void restoreConsent() throws JobcelisException, IOException {
        doDelete("/api/v1/me/object");
    }

    // ── Health ─────────────────────────────────────────────────────────────

    /** Check API health. */
    public JsonObject health() throws JobcelisException, IOException {
        return get("/health");
    }

    /** Get platform status. */
    public JsonObject status() throws JobcelisException, IOException {
        return get("/status");
    }

    // ── Private HTTP helpers ──────────────────────────────────────────────

    private JsonObject get(String path) throws JobcelisException, IOException {
        return get(path, Map.of());
    }

    private JsonObject get(String path, Map<String, String> params) throws JobcelisException, IOException {
        return request("GET", path, params, null);
    }

    private JsonObject post(String path, Map<String, Object> body) throws JobcelisException, IOException {
        return request("POST", path, Map.of(), body);
    }

    private JsonObject patch(String path, Map<String, Object> body) throws JobcelisException, IOException {
        return request("PATCH", path, Map.of(), body);
    }

    private void doDelete(String path) throws JobcelisException, IOException {
        request("DELETE", path, Map.of(), null);
    }

    private String getRaw(String path, Map<String, String> params) throws JobcelisException, IOException {
        String url = buildURL(path, params);
        HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
        conn.setRequestMethod("GET");
        conn.setRequestProperty("X-Api-Key", apiKey);
        if (authToken != null) {
            conn.setRequestProperty("Authorization", "Bearer " + authToken);
        }
        return handleRawResponse(conn);
    }

    private JsonObject publicPost(String path, Map<String, Object> body) throws JobcelisException, IOException {
        String url = baseURL + path;
        HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
        conn.setRequestMethod("POST");
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setDoOutput(true);

        try (OutputStream os = conn.getOutputStream()) {
            os.write(GSON.toJson(body).getBytes(StandardCharsets.UTF_8));
        }

        return handleResponse(conn);
    }

    private JsonObject request(String method, String path, Map<String, String> params, Map<String, Object> body) throws JobcelisException, IOException {
        String url = buildURL(path, params);
        HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
        conn.setRequestMethod(method.equals("PATCH") ? "POST" : method);
        if (method.equals("PATCH")) {
            conn.setRequestProperty("X-HTTP-Method-Override", "PATCH");
        }
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setRequestProperty("Accept", "application/json");
        conn.setRequestProperty("X-Api-Key", apiKey);
        if (authToken != null) {
            conn.setRequestProperty("Authorization", "Bearer " + authToken);
        }

        if (body != null && (method.equals("POST") || method.equals("PATCH") || method.equals("PUT"))) {
            conn.setDoOutput(true);
            try (OutputStream os = conn.getOutputStream()) {
                os.write(GSON.toJson(body).getBytes(StandardCharsets.UTF_8));
            }
        }

        return handleResponse(conn);
    }

    private JsonObject handleResponse(HttpURLConnection conn) throws JobcelisException, IOException {
        int statusCode = conn.getResponseCode();

        if (statusCode == 204) {
            return new JsonObject();
        }

        String responseBody = readStream(statusCode >= 400 ? conn.getErrorStream() : conn.getInputStream());

        if (statusCode >= 400) {
            throw new JobcelisException(statusCode, responseBody);
        }

        JsonElement element = JsonParser.parseString(responseBody);
        return element.isJsonObject() ? element.getAsJsonObject() : new JsonObject();
    }

    private String handleRawResponse(HttpURLConnection conn) throws JobcelisException, IOException {
        int statusCode = conn.getResponseCode();

        if (statusCode >= 400) {
            String errorBody = readStream(conn.getErrorStream());
            throw new JobcelisException(statusCode, errorBody);
        }

        return readStream(conn.getInputStream());
    }

    private String buildURL(String path, Map<String, String> params) {
        StringBuilder sb = new StringBuilder(baseURL).append(path);
        if (params != null && !params.isEmpty()) {
            sb.append("?");
            boolean first = true;
            for (Map.Entry<String, String> entry : params.entrySet()) {
                if (entry.getValue() == null) continue;
                if (!first) sb.append("&");
                sb.append(URLEncoder.encode(entry.getKey(), StandardCharsets.UTF_8));
                sb.append("=");
                sb.append(URLEncoder.encode(entry.getValue(), StandardCharsets.UTF_8));
                first = false;
            }
        }
        return sb.toString();
    }

    private static String readStream(java.io.InputStream stream) throws IOException {
        if (stream == null) return "";
        try (Scanner scanner = new Scanner(stream, StandardCharsets.UTF_8.name())) {
            scanner.useDelimiter("\\A");
            return scanner.hasNext() ? scanner.next() : "";
        }
    }
}
