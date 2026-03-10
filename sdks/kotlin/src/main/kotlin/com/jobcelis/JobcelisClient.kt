package com.jobcelis

import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.Closeable
import java.net.URLEncoder

/**
 * Client for the Jobcelis Event Infrastructure Platform API.
 *
 * All API calls go to `https://jobcelis.com` by default.
 *
 * ```kotlin
 * val client = JobcelisClient("your_api_key")
 * val event = client.sendEvent("order.created", mapOf("order_id" to "123"))
 * ```
 *
 * @property apiKey Your Jobcelis API key.
 * @property baseURL Base URL of the Jobcelis API.
 */
class JobcelisClient(
    private val apiKey: String,
    baseURL: String = "https://jobcelis.com",
    private val httpClient: OkHttpClient = OkHttpClient()
) : Closeable {

    private val baseURL = baseURL.trimEnd('/')
    private var authToken: String? = null
    private val gson = Gson()
    private val jsonMediaType = "application/json".toMediaType()

    /** Set JWT bearer token for authenticated requests. */
    fun setAuthToken(token: String) {
        authToken = token
    }

    override fun close() {
        httpClient.dispatcher.executorService.shutdown()
        httpClient.connectionPool.evictAll()
    }

    // ── Auth ──────────────────────────────────────────────────────────────

    /** Register a new account. Does not use API key auth. */
    suspend fun register(email: String, password: String, name: String? = null): JsonObject {
        val body = mutableMapOf<String, Any>("email" to email, "password" to password)
        if (name != null) body["name"] = name
        return publicPost("/api/v1/auth/register", body)
    }

    /** Log in and receive JWT + refresh token. */
    suspend fun login(email: String, password: String): JsonObject =
        publicPost("/api/v1/auth/login", mapOf("email" to email, "password" to password))

    /** Refresh an expired JWT. */
    suspend fun refreshToken(refreshToken: String): JsonObject =
        publicPost("/api/v1/auth/refresh", mapOf("refresh_token" to refreshToken))

    /** Verify MFA code. */
    suspend fun verifyMfa(token: String, code: String): JsonObject =
        post("/api/v1/auth/mfa/verify", mapOf("token" to token, "code" to code))

    // ── Events ────────────────────────────────────────────────────────────

    /** Send a single event. */
    suspend fun sendEvent(topic: String, payload: Map<String, Any>): JsonObject =
        post("/api/v1/events", mapOf("topic" to topic, "payload" to payload))

    /** Send up to 1000 events in a batch. */
    suspend fun sendEvents(events: List<Map<String, Any>>): JsonObject =
        post("/api/v1/events/batch", mapOf("events" to events))

    /** Get event details. */
    suspend fun getEvent(eventId: String): JsonObject =
        get("/api/v1/events/$eventId")

    /** List events with cursor pagination. */
    suspend fun listEvents(limit: Int = 50, cursor: String? = null): JsonObject =
        get("/api/v1/events", buildParams("limit" to "$limit", "cursor" to cursor))

    /** Delete an event. */
    suspend fun deleteEvent(eventId: String) {
        doDelete("/api/v1/events/$eventId")
    }

    // ── Simulate ──────────────────────────────────────────────────────────

    /** Simulate sending an event (dry run). */
    suspend fun simulateEvent(topic: String, payload: Map<String, Any>): JsonObject =
        post("/api/v1/simulate", mapOf("topic" to topic, "payload" to payload))

    // ── Webhooks ──────────────────────────────────────────────────────────

    /** Create a webhook. */
    suspend fun createWebhook(
        url: String,
        extra: Map<String, Any>? = null,
        rateLimit: Map<String, Int>? = null
    ): JsonObject {
        val body = mutableMapOf<String, Any>("url" to url)
        extra?.let { body.putAll(it) }
        rateLimit?.let { body["rate_limit"] = it }
        return post("/api/v1/webhooks", body)
    }

    /** Get webhook details. */
    suspend fun getWebhook(webhookId: String): JsonObject =
        get("/api/v1/webhooks/$webhookId")

    /** List webhooks. */
    suspend fun listWebhooks(limit: Int = 50, cursor: String? = null): JsonObject =
        get("/api/v1/webhooks", buildParams("limit" to "$limit", "cursor" to cursor))

    /** Update a webhook. */
    suspend fun updateWebhook(
        webhookId: String,
        data: Map<String, Any>,
        rateLimit: Map<String, Int>? = null
    ): JsonObject {
        val body = data.toMutableMap()
        rateLimit?.let { body["rate_limit"] = it }
        return patch("/api/v1/webhooks/$webhookId", body)
    }

    /** Delete a webhook. */
    suspend fun deleteWebhook(webhookId: String) {
        doDelete("/api/v1/webhooks/$webhookId")
    }

    /** Get health status for a webhook. */
    suspend fun webhookHealth(webhookId: String): JsonObject =
        get("/api/v1/webhooks/$webhookId/health")

    /** List available webhook templates. */
    suspend fun webhookTemplates(): JsonObject =
        get("/api/v1/webhooks/templates")

    /** Send a test delivery to a webhook. */
    suspend fun testWebhook(webhookId: String): JsonObject =
        post("/api/v1/webhooks/$webhookId/test", emptyMap())

    // ── Deliveries ────────────────────────────────────────────────────────

    /** List deliveries. */
    suspend fun listDeliveries(limit: Int = 50, cursor: String? = null, status: String? = null): JsonObject =
        get("/api/v1/deliveries", buildParams("limit" to "$limit", "cursor" to cursor, "status" to status))

    /** Retry a failed delivery. */
    suspend fun retryDelivery(deliveryId: String): JsonObject =
        post("/api/v1/deliveries/$deliveryId/retry", emptyMap())

    // ── Dead Letters ──────────────────────────────────────────────────────

    /** List dead letters. */
    suspend fun listDeadLetters(limit: Int = 50, cursor: String? = null): JsonObject =
        get("/api/v1/dead-letters", buildParams("limit" to "$limit", "cursor" to cursor))

    /** Get dead letter details. */
    suspend fun getDeadLetter(deadLetterId: String): JsonObject =
        get("/api/v1/dead-letters/$deadLetterId")

    /** Retry a dead letter. */
    suspend fun retryDeadLetter(deadLetterId: String): JsonObject =
        post("/api/v1/dead-letters/$deadLetterId/retry", emptyMap())

    /** Mark a dead letter as resolved. */
    suspend fun resolveDeadLetter(deadLetterId: String): JsonObject =
        patch("/api/v1/dead-letters/$deadLetterId/resolve", emptyMap())

    // ── Replays ───────────────────────────────────────────────────────────

    /** Start an event replay. */
    suspend fun createReplay(topic: String, fromDate: String, toDate: String, webhookId: String? = null): JsonObject {
        val body = mutableMapOf<String, Any>("topic" to topic, "from_date" to fromDate, "to_date" to toDate)
        if (webhookId != null) body["webhook_id"] = webhookId
        return post("/api/v1/replays", body)
    }

    /** List replays. */
    suspend fun listReplays(limit: Int = 50, cursor: String? = null): JsonObject =
        get("/api/v1/replays", buildParams("limit" to "$limit", "cursor" to cursor))

    /** Get replay details. */
    suspend fun getReplay(replayId: String): JsonObject =
        get("/api/v1/replays/$replayId")

    /** Cancel a replay. */
    suspend fun cancelReplay(replayId: String) {
        doDelete("/api/v1/replays/$replayId")
    }

    // ── Jobs ──────────────────────────────────────────────────────────────

    /** Create a scheduled job. */
    suspend fun createJob(name: String, queue: String, cronExpression: String, extra: Map<String, Any>? = null): JsonObject {
        val body = mutableMapOf<String, Any>("name" to name, "queue" to queue, "cron_expression" to cronExpression)
        extra?.let { body.putAll(it) }
        return post("/api/v1/jobs", body)
    }

    /** List scheduled jobs. */
    suspend fun listJobs(limit: Int = 50, cursor: String? = null): JsonObject =
        get("/api/v1/jobs", buildParams("limit" to "$limit", "cursor" to cursor))

    /** Get job details. */
    suspend fun getJob(jobId: String): JsonObject =
        get("/api/v1/jobs/$jobId")

    /** Update a scheduled job. */
    suspend fun updateJob(jobId: String, data: Map<String, Any>): JsonObject =
        patch("/api/v1/jobs/$jobId", data)

    /** Delete a scheduled job. */
    suspend fun deleteJob(jobId: String) {
        doDelete("/api/v1/jobs/$jobId")
    }

    /** List runs for a scheduled job. */
    suspend fun listJobRuns(jobId: String, limit: Int = 50): JsonObject =
        get("/api/v1/jobs/$jobId/runs", buildParams("limit" to "$limit"))

    /** Preview next occurrences for a cron expression. */
    suspend fun cronPreview(expression: String, count: Int = 5): JsonObject =
        get("/api/v1/jobs/cron-preview", buildParams("expression" to expression, "count" to "$count"))

    // ── Pipelines ─────────────────────────────────────────────────────────

    /** Create an event pipeline. */
    suspend fun createPipeline(name: String, topics: List<String>, steps: List<Map<String, Any>>): JsonObject =
        post("/api/v1/pipelines", mapOf("name" to name, "topics" to topics, "steps" to steps))

    /** List pipelines. */
    suspend fun listPipelines(limit: Int = 50, cursor: String? = null): JsonObject =
        get("/api/v1/pipelines", buildParams("limit" to "$limit", "cursor" to cursor))

    /** Get pipeline details. */
    suspend fun getPipeline(pipelineId: String): JsonObject =
        get("/api/v1/pipelines/$pipelineId")

    /** Update a pipeline. */
    suspend fun updatePipeline(pipelineId: String, data: Map<String, Any>): JsonObject =
        patch("/api/v1/pipelines/$pipelineId", data)

    /** Delete a pipeline. */
    suspend fun deletePipeline(pipelineId: String) {
        doDelete("/api/v1/pipelines/$pipelineId")
    }

    /** Test a pipeline with a sample payload. */
    suspend fun testPipeline(pipelineId: String, payload: Map<String, Any>): JsonObject =
        post("/api/v1/pipelines/$pipelineId/test", payload)

    // ── Event Schemas ─────────────────────────────────────────────────────

    /** Create an event schema. */
    suspend fun createEventSchema(topic: String, schema: Map<String, Any>): JsonObject =
        post("/api/v1/event-schemas", mapOf("topic" to topic, "schema" to schema))

    /** List event schemas. */
    suspend fun listEventSchemas(limit: Int = 50, cursor: String? = null): JsonObject =
        get("/api/v1/event-schemas", buildParams("limit" to "$limit", "cursor" to cursor))

    /** Get event schema details. */
    suspend fun getEventSchema(schemaId: String): JsonObject =
        get("/api/v1/event-schemas/$schemaId")

    /** Update an event schema. */
    suspend fun updateEventSchema(schemaId: String, data: Map<String, Any>): JsonObject =
        patch("/api/v1/event-schemas/$schemaId", data)

    /** Delete an event schema. */
    suspend fun deleteEventSchema(schemaId: String) {
        doDelete("/api/v1/event-schemas/$schemaId")
    }

    /** Validate a payload against the schema for a topic. */
    suspend fun validatePayload(topic: String, payload: Map<String, Any>): JsonObject =
        post("/api/v1/event-schemas/validate", mapOf("topic" to topic, "payload" to payload))

    // ── Sandbox ───────────────────────────────────────────────────────────

    /** List sandbox endpoints. */
    suspend fun listSandboxEndpoints(): JsonObject =
        get("/api/v1/sandbox-endpoints")

    /** Create a sandbox endpoint. */
    suspend fun createSandboxEndpoint(name: String? = null): JsonObject {
        val body = mutableMapOf<String, Any>()
        if (name != null) body["name"] = name
        return post("/api/v1/sandbox-endpoints", body)
    }

    /** Delete a sandbox endpoint. */
    suspend fun deleteSandboxEndpoint(endpointId: String) {
        doDelete("/api/v1/sandbox-endpoints/$endpointId")
    }

    /** List requests received by a sandbox endpoint. */
    suspend fun listSandboxRequests(endpointId: String, limit: Int = 50): JsonObject =
        get("/api/v1/sandbox-endpoints/$endpointId/requests", buildParams("limit" to "$limit"))

    // ── Analytics ─────────────────────────────────────────────────────────

    /** Get events per day for the last N days. */
    suspend fun eventsPerDay(days: Int = 7): JsonObject =
        get("/api/v1/analytics/events-per-day", buildParams("days" to "$days"))

    /** Get deliveries per day for the last N days. */
    suspend fun deliveriesPerDay(days: Int = 7): JsonObject =
        get("/api/v1/analytics/deliveries-per-day", buildParams("days" to "$days"))

    /** Get top topics by event count. */
    suspend fun topTopics(limit: Int = 10): JsonObject =
        get("/api/v1/analytics/top-topics", buildParams("limit" to "$limit"))

    /** Get webhook delivery statistics. */
    suspend fun webhookStats(): JsonObject =
        get("/api/v1/analytics/webhook-stats")

    // ── Project (current) ─────────────────────────────────────────────────

    /** Get current project details. */
    suspend fun getProject(): JsonObject =
        get("/api/v1/project")

    /** Update current project. */
    suspend fun updateProject(data: Map<String, Any>): JsonObject =
        patch("/api/v1/project", data)

    /** List all topics in the current project. */
    suspend fun listTopics(): JsonObject =
        get("/api/v1/topics")

    /** Get the current API token info. */
    suspend fun getToken(): JsonObject =
        get("/api/v1/token")

    /** Regenerate the API token. */
    suspend fun regenerateToken(): JsonObject =
        post("/api/v1/token/regenerate", emptyMap())

    // ── Projects (multi) ──────────────────────────────────────────────────

    /** List all projects. */
    suspend fun listProjects(): JsonObject =
        get("/api/v1/projects")

    /** Create a new project. */
    suspend fun createProject(name: String): JsonObject =
        post("/api/v1/projects", mapOf("name" to name))

    /** Get project by ID. */
    suspend fun getProjectById(projectId: String): JsonObject =
        get("/api/v1/projects/$projectId")

    /** Update a project by ID. */
    suspend fun updateProjectById(projectId: String, data: Map<String, Any>): JsonObject =
        patch("/api/v1/projects/$projectId", data)

    /** Delete a project. */
    suspend fun deleteProject(projectId: String) {
        doDelete("/api/v1/projects/$projectId")
    }

    /** Set a project as the default. */
    suspend fun setDefaultProject(projectId: String): JsonObject =
        patch("/api/v1/projects/$projectId/default", emptyMap())

    // ── Teams ─────────────────────────────────────────────────────────────

    /** List members of a project. */
    suspend fun listMembers(projectId: String): JsonObject =
        get("/api/v1/projects/$projectId/members")

    /** Add a member to a project. */
    suspend fun addMember(projectId: String, email: String, role: String = "member"): JsonObject =
        post("/api/v1/projects/$projectId/members", mapOf("email" to email, "role" to role))

    /** Update a member's role. */
    suspend fun updateMember(projectId: String, memberId: String, role: String): JsonObject =
        patch("/api/v1/projects/$projectId/members/$memberId", mapOf("role" to role))

    /** Remove a member from a project. */
    suspend fun removeMember(projectId: String, memberId: String) {
        doDelete("/api/v1/projects/$projectId/members/$memberId")
    }

    // ── Invitations ───────────────────────────────────────────────────────

    /** List pending invitations for the current user. */
    suspend fun listPendingInvitations(): JsonObject =
        get("/api/v1/invitations/pending")

    /** Accept an invitation. */
    suspend fun acceptInvitation(invitationId: String): JsonObject =
        post("/api/v1/invitations/$invitationId/accept", emptyMap())

    /** Reject an invitation. */
    suspend fun rejectInvitation(invitationId: String): JsonObject =
        post("/api/v1/invitations/$invitationId/reject", emptyMap())

    // ── Audit ─────────────────────────────────────────────────────────────

    /** List audit log entries. */
    suspend fun listAuditLogs(limit: Int = 50, cursor: String? = null): JsonObject =
        get("/api/v1/audit-log", buildParams("limit" to "$limit", "cursor" to cursor))

    // ── Embed Tokens ──────────────────────────────────────────────────────

    /** List embed tokens. */
    suspend fun listEmbedTokens(): JsonObject =
        get("/api/v1/embed/tokens")

    /** Create an embed token. */
    suspend fun createEmbedToken(config: JsonObject): JsonObject =
        post("/api/v1/embed/tokens", gson.fromJson(config, Map::class.java) as Map<String, Any>)

    /** Revoke an embed token. */
    suspend fun revokeEmbedToken(id: String) {
        doDelete("/api/v1/embed/tokens/$id")
    }

    // ── Notification Channels ─────────────────────────────────────────────

    /** Get the notification channel configuration. */
    suspend fun getNotificationChannel(): JsonObject =
        get("/api/v1/notification-channels")

    /** Create or update the notification channel configuration. */
    suspend fun upsertNotificationChannel(config: JsonObject): JsonObject =
        put("/api/v1/notification-channels", gson.fromJson(config, Map::class.java) as Map<String, Any>)

    /** Delete the notification channel configuration. */
    suspend fun deleteNotificationChannel() {
        doDelete("/api/v1/notification-channels")
    }

    /** Send a test notification to the configured channel. */
    suspend fun testNotificationChannel(): JsonObject =
        post("/api/v1/notification-channels/test", emptyMap())

    // ── Export ─────────────────────────────────────────────────────────────

    /** Export events as CSV or JSON. Returns raw string. */
    suspend fun exportEvents(format: String = "csv"): String =
        getRaw("/api/v1/export/events", buildParams("format" to format))

    /** Export deliveries as CSV or JSON. Returns raw string. */
    suspend fun exportDeliveries(format: String = "csv"): String =
        getRaw("/api/v1/export/deliveries", buildParams("format" to format))

    /** Export jobs as CSV or JSON. Returns raw string. */
    suspend fun exportJobs(format: String = "csv"): String =
        getRaw("/api/v1/export/jobs", buildParams("format" to format))

    /** Export audit log as CSV or JSON. Returns raw string. */
    suspend fun exportAuditLog(format: String = "csv"): String =
        getRaw("/api/v1/export/audit-log", buildParams("format" to format))

    // ── GDPR ──────────────────────────────────────────────────────────────

    /** Get current user consent status. */
    suspend fun getConsents(): JsonObject =
        get("/api/v1/me/consents")

    /** Accept consent for a specific purpose. */
    suspend fun acceptConsent(purpose: String): JsonObject =
        post("/api/v1/me/consents/$purpose/accept", emptyMap())

    /** Export all personal data (GDPR data portability). */
    suspend fun exportMyData(): JsonObject =
        get("/api/v1/me/data")

    /** Request restriction of data processing. */
    suspend fun restrictProcessing(): JsonObject =
        post("/api/v1/me/restrict", emptyMap())

    /** Lift restriction on data processing. */
    suspend fun liftRestriction() {
        doDelete("/api/v1/me/restrict")
    }

    /** Object to data processing. */
    suspend fun objectToProcessing(): JsonObject =
        post("/api/v1/me/object", emptyMap())

    /** Withdraw objection to data processing. */
    suspend fun restoreConsent() {
        doDelete("/api/v1/me/object")
    }

    // ── Health ─────────────────────────────────────────────────────────────

    /** Check API health. */
    suspend fun health(): JsonObject =
        get("/health")

    /** Get platform status. */
    suspend fun status(): JsonObject =
        get("/status")

    // ── Private HTTP helpers ──────────────────────────────────────────────

    private suspend fun get(path: String, params: Map<String, String> = emptyMap()): JsonObject =
        request("GET", path, params)

    private suspend fun post(path: String, body: Map<String, Any>): JsonObject =
        request("POST", path, body = body)

    private suspend fun put(path: String, body: Map<String, Any>): JsonObject =
        request("PUT", path, body = body)

    private suspend fun patch(path: String, body: Map<String, Any>): JsonObject =
        request("PATCH", path, body = body)

    private suspend fun doDelete(path: String) {
        request("DELETE", path)
    }

    private suspend fun getRaw(path: String, params: Map<String, String> = emptyMap()): String =
        withContext(Dispatchers.IO) {
            val url = buildURL(path, params)
            val request = Request.Builder()
                .url(url)
                .get()
                .addHeader("X-Api-Key", apiKey)
                .apply { authToken?.let { addHeader("Authorization", "Bearer $it") } }
                .build()

            httpClient.newCall(request).execute().use { response ->
                val responseBody = response.body?.string() ?: ""
                if (!response.isSuccessful) {
                    throw JobcelisException(response.code, responseBody)
                }
                responseBody
            }
        }

    private suspend fun publicPost(path: String, body: Map<String, Any>): JsonObject =
        withContext(Dispatchers.IO) {
            val url = "$baseURL$path"
            val jsonBody = gson.toJson(body).toRequestBody(jsonMediaType)
            val request = Request.Builder()
                .url(url)
                .post(jsonBody)
                .addHeader("Content-Type", "application/json")
                .build()

            httpClient.newCall(request).execute().use { response ->
                handleResponse(response)
            }
        }

    private suspend fun request(
        method: String,
        path: String,
        params: Map<String, String> = emptyMap(),
        body: Map<String, Any>? = null
    ): JsonObject = withContext(Dispatchers.IO) {
        val url = buildURL(path, params)
        val jsonBody = if (body != null && method in listOf("POST", "PATCH", "PUT")) {
            gson.toJson(body).toRequestBody(jsonMediaType)
        } else null

        val request = Request.Builder()
            .url(url)
            .method(method, jsonBody ?: if (method in listOf("POST", "PATCH", "PUT")) "{}".toRequestBody(jsonMediaType) else null)
            .addHeader("Content-Type", "application/json")
            .addHeader("Accept", "application/json")
            .addHeader("X-Api-Key", apiKey)
            .apply { authToken?.let { addHeader("Authorization", "Bearer $it") } }
            .build()

        httpClient.newCall(request).execute().use { response ->
            handleResponse(response)
        }
    }

    private fun handleResponse(response: okhttp3.Response): JsonObject {
        val statusCode = response.code
        val responseBody = response.body?.string() ?: ""

        if (statusCode == 204) return JsonObject()

        if (statusCode >= 400) {
            throw JobcelisException(statusCode, responseBody)
        }

        if (responseBody.isEmpty()) return JsonObject()

        val element = JsonParser.parseString(responseBody)
        return if (element.isJsonObject) element.asJsonObject else JsonObject()
    }

    private fun buildURL(path: String, params: Map<String, String>): String {
        val sb = StringBuilder("$baseURL$path")
        val filtered = params.filter { it.value.isNotEmpty() }
        if (filtered.isNotEmpty()) {
            sb.append("?")
            sb.append(filtered.entries.joinToString("&") { (k, v) ->
                "${URLEncoder.encode(k, "UTF-8")}=${URLEncoder.encode(v, "UTF-8")}"
            })
        }
        return sb.toString()
    }

    private fun buildParams(vararg pairs: Pair<String, String?>): Map<String, String> =
        pairs.filter { it.second != null }.associate { it.first to it.second!! }
}
