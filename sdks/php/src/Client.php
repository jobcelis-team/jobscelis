<?php

declare(strict_types=1);

namespace Jobcelis;

/**
 * Client for the Jobcelis Event Infrastructure Platform API.
 *
 * All API calls go to https://jobcelis.com by default.
 */
class Client
{
    private string $apiKey;
    private string $baseUrl;
    private int $timeout;
    private ?string $authToken = null;

    /**
     * @param string $apiKey   Your Jobcelis API key.
     * @param string $baseUrl  Base URL of the Jobcelis API (default: https://jobcelis.com).
     * @param int    $timeout  Request timeout in seconds (default: 30).
     */
    public function __construct(
        string $apiKey,
        string $baseUrl = 'https://jobcelis.com',
        int $timeout = 30,
    ) {
        $this->apiKey = $apiKey;
        $this->baseUrl = rtrim($baseUrl, '/');
        $this->timeout = $timeout;
    }

    // -------------------------------------------------------------------------
    // Auth
    // -------------------------------------------------------------------------

    /**
     * Register a new account. Does not use API key auth.
     */
    public function register(string $email, string $password, ?string $name = null): array
    {
        $body = ['email' => $email, 'password' => $password];
        if ($name !== null) {
            $body['name'] = $name;
        }
        return $this->publicPost('/api/v1/auth/register', $body);
    }

    /**
     * Log in and receive JWT + refresh token. Does not use API key auth.
     */
    public function login(string $email, string $password): array
    {
        return $this->publicPost('/api/v1/auth/login', [
            'email' => $email,
            'password' => $password,
        ]);
    }

    /**
     * Refresh an expired JWT using a refresh token. Does not use API key auth.
     */
    public function refreshToken(string $refreshToken): array
    {
        return $this->publicPost('/api/v1/auth/refresh', [
            'refresh_token' => $refreshToken,
        ]);
    }

    /**
     * Verify MFA code. Requires Bearer token set via setAuthToken().
     */
    public function verifyMfa(string $token, string $code): array
    {
        return $this->post('/api/v1/auth/mfa/verify', [
            'token' => $token,
            'code' => $code,
        ]);
    }

    /**
     * Set JWT bearer token for authenticated requests.
     */
    public function setAuthToken(string $token): void
    {
        $this->authToken = $token;
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /**
     * Send a single event.
     */
    public function sendEvent(string $topic, array $payload, array $extra = []): array
    {
        $body = array_merge(['topic' => $topic, 'payload' => $payload], $extra);
        return $this->post('/api/v1/events', $body);
    }

    /**
     * Send up to 1000 events in a batch.
     */
    public function sendEvents(array $events): array
    {
        return $this->post('/api/v1/events/batch', ['events' => $events]);
    }

    /**
     * Get event details.
     */
    public function getEvent(string $eventId): array
    {
        return $this->get("/api/v1/events/{$eventId}");
    }

    /**
     * List events with cursor pagination.
     */
    public function listEvents(int $limit = 50, ?string $cursor = null): array
    {
        return $this->get('/api/v1/events', ['limit' => $limit, 'cursor' => $cursor]);
    }

    /**
     * Deactivate an event.
     */
    public function deleteEvent(string $eventId): void
    {
        $this->doDelete("/api/v1/events/{$eventId}");
    }

    // -------------------------------------------------------------------------
    // Simulate
    // -------------------------------------------------------------------------

    /**
     * Simulate sending an event (dry run).
     */
    public function simulateEvent(string $topic, array $payload): array
    {
        return $this->post('/api/v1/simulate', [
            'topic' => $topic,
            'payload' => $payload,
        ]);
    }

    // -------------------------------------------------------------------------
    // Webhooks
    // -------------------------------------------------------------------------

    /**
     * Create a webhook.
     */
    public function createWebhook(string $url, array $extra = []): array
    {
        $body = array_merge(['url' => $url], $extra);
        return $this->post('/api/v1/webhooks', $body);
    }

    /**
     * Get webhook details.
     */
    public function getWebhook(string $webhookId): array
    {
        return $this->get("/api/v1/webhooks/{$webhookId}");
    }

    /**
     * List webhooks.
     */
    public function listWebhooks(int $limit = 50, ?string $cursor = null): array
    {
        return $this->get('/api/v1/webhooks', ['limit' => $limit, 'cursor' => $cursor]);
    }

    /**
     * Update a webhook.
     */
    public function updateWebhook(string $webhookId, array $data): array
    {
        return $this->patch("/api/v1/webhooks/{$webhookId}", $data);
    }

    /**
     * Deactivate a webhook.
     */
    public function deleteWebhook(string $webhookId): void
    {
        $this->doDelete("/api/v1/webhooks/{$webhookId}");
    }

    /**
     * Get health status for a webhook.
     */
    public function webhookHealth(string $webhookId): array
    {
        return $this->get("/api/v1/webhooks/{$webhookId}/health");
    }

    /**
     * List available webhook templates.
     */
    public function webhookTemplates(): array
    {
        return $this->get('/api/v1/webhooks/templates');
    }

    // -------------------------------------------------------------------------
    // Deliveries
    // -------------------------------------------------------------------------

    /**
     * List deliveries.
     */
    public function listDeliveries(int $limit = 50, ?string $cursor = null, array $filters = []): array
    {
        $params = array_merge(['limit' => $limit, 'cursor' => $cursor], $filters);
        return $this->get('/api/v1/deliveries', $params);
    }

    /**
     * Retry a failed delivery.
     */
    public function retryDelivery(string $deliveryId): void
    {
        $this->post("/api/v1/deliveries/{$deliveryId}/retry", []);
    }

    // -------------------------------------------------------------------------
    // Dead Letters
    // -------------------------------------------------------------------------

    /**
     * List dead letters.
     */
    public function listDeadLetters(int $limit = 50, ?string $cursor = null): array
    {
        return $this->get('/api/v1/dead-letters', ['limit' => $limit, 'cursor' => $cursor]);
    }

    /**
     * Get dead letter details.
     */
    public function getDeadLetter(string $deadLetterId): array
    {
        return $this->get("/api/v1/dead-letters/{$deadLetterId}");
    }

    /**
     * Retry a dead letter.
     */
    public function retryDeadLetter(string $deadLetterId): void
    {
        $this->post("/api/v1/dead-letters/{$deadLetterId}/retry", []);
    }

    /**
     * Mark a dead letter as resolved.
     */
    public function resolveDeadLetter(string $deadLetterId): void
    {
        $this->patch("/api/v1/dead-letters/{$deadLetterId}/resolve", []);
    }

    // -------------------------------------------------------------------------
    // Replays
    // -------------------------------------------------------------------------

    /**
     * Start an event replay.
     */
    public function createReplay(string $topic, string $fromDate, string $toDate, ?string $webhookId = null): array
    {
        $body = ['topic' => $topic, 'from_date' => $fromDate, 'to_date' => $toDate];
        if ($webhookId !== null) {
            $body['webhook_id'] = $webhookId;
        }
        return $this->post('/api/v1/replays', $body);
    }

    /**
     * List replays.
     */
    public function listReplays(int $limit = 50, ?string $cursor = null): array
    {
        return $this->get('/api/v1/replays', ['limit' => $limit, 'cursor' => $cursor]);
    }

    /**
     * Get replay details.
     */
    public function getReplay(string $replayId): array
    {
        return $this->get("/api/v1/replays/{$replayId}");
    }

    /**
     * Cancel a replay.
     */
    public function cancelReplay(string $replayId): void
    {
        $this->doDelete("/api/v1/replays/{$replayId}");
    }

    // -------------------------------------------------------------------------
    // Jobs
    // -------------------------------------------------------------------------

    /**
     * Create a scheduled job.
     */
    public function createJob(string $name, string $queue, string $cronExpression, array $extra = []): array
    {
        $body = array_merge([
            'name' => $name,
            'queue' => $queue,
            'cron_expression' => $cronExpression,
        ], $extra);
        return $this->post('/api/v1/jobs', $body);
    }

    /**
     * List scheduled jobs.
     */
    public function listJobs(int $limit = 50, ?string $cursor = null): array
    {
        return $this->get('/api/v1/jobs', ['limit' => $limit, 'cursor' => $cursor]);
    }

    /**
     * Get job details.
     */
    public function getJob(string $jobId): array
    {
        return $this->get("/api/v1/jobs/{$jobId}");
    }

    /**
     * Update a scheduled job.
     */
    public function updateJob(string $jobId, array $data): array
    {
        return $this->patch("/api/v1/jobs/{$jobId}", $data);
    }

    /**
     * Delete a scheduled job.
     */
    public function deleteJob(string $jobId): void
    {
        $this->doDelete("/api/v1/jobs/{$jobId}");
    }

    /**
     * List runs for a scheduled job.
     */
    public function listJobRuns(string $jobId, int $limit = 50): array
    {
        return $this->get("/api/v1/jobs/{$jobId}/runs", ['limit' => $limit]);
    }

    /**
     * Preview next occurrences for a cron expression.
     */
    public function cronPreview(string $expression, int $count = 5): array
    {
        return $this->get('/api/v1/jobs/cron-preview', [
            'expression' => $expression,
            'count' => $count,
        ]);
    }

    // -------------------------------------------------------------------------
    // Pipelines
    // -------------------------------------------------------------------------

    /**
     * Create an event pipeline.
     */
    public function createPipeline(string $name, array $topics, array $steps, array $extra = []): array
    {
        $body = array_merge([
            'name' => $name,
            'topics' => $topics,
            'steps' => $steps,
        ], $extra);
        return $this->post('/api/v1/pipelines', $body);
    }

    /**
     * List pipelines.
     */
    public function listPipelines(int $limit = 50, ?string $cursor = null): array
    {
        return $this->get('/api/v1/pipelines', ['limit' => $limit, 'cursor' => $cursor]);
    }

    /**
     * Get pipeline details.
     */
    public function getPipeline(string $pipelineId): array
    {
        return $this->get("/api/v1/pipelines/{$pipelineId}");
    }

    /**
     * Update a pipeline.
     */
    public function updatePipeline(string $pipelineId, array $data): array
    {
        return $this->patch("/api/v1/pipelines/{$pipelineId}", $data);
    }

    /**
     * Delete a pipeline.
     */
    public function deletePipeline(string $pipelineId): void
    {
        $this->doDelete("/api/v1/pipelines/{$pipelineId}");
    }

    /**
     * Test a pipeline with a sample payload.
     */
    public function testPipeline(string $pipelineId, array $payload): array
    {
        return $this->post("/api/v1/pipelines/{$pipelineId}/test", $payload);
    }

    // -------------------------------------------------------------------------
    // Event Schemas
    // -------------------------------------------------------------------------

    /**
     * Create an event schema.
     */
    public function createEventSchema(string $topic, array $schema, array $extra = []): array
    {
        $body = array_merge(['topic' => $topic, 'schema' => $schema], $extra);
        return $this->post('/api/v1/event-schemas', $body);
    }

    /**
     * List event schemas.
     */
    public function listEventSchemas(int $limit = 50, ?string $cursor = null): array
    {
        return $this->get('/api/v1/event-schemas', ['limit' => $limit, 'cursor' => $cursor]);
    }

    /**
     * Get event schema details.
     */
    public function getEventSchema(string $schemaId): array
    {
        return $this->get("/api/v1/event-schemas/{$schemaId}");
    }

    /**
     * Update an event schema.
     */
    public function updateEventSchema(string $schemaId, array $data): array
    {
        return $this->patch("/api/v1/event-schemas/{$schemaId}", $data);
    }

    /**
     * Delete an event schema.
     */
    public function deleteEventSchema(string $schemaId): void
    {
        $this->doDelete("/api/v1/event-schemas/{$schemaId}");
    }

    /**
     * Validate a payload against the schema for a topic.
     */
    public function validatePayload(string $topic, array $payload): array
    {
        return $this->post('/api/v1/event-schemas/validate', [
            'topic' => $topic,
            'payload' => $payload,
        ]);
    }

    // -------------------------------------------------------------------------
    // Sandbox
    // -------------------------------------------------------------------------

    /**
     * List sandbox endpoints.
     */
    public function listSandboxEndpoints(): array
    {
        return $this->get('/api/v1/sandbox-endpoints');
    }

    /**
     * Create a sandbox endpoint.
     */
    public function createSandboxEndpoint(?string $name = null): array
    {
        $body = [];
        if ($name !== null) {
            $body['name'] = $name;
        }
        return $this->post('/api/v1/sandbox-endpoints', $body);
    }

    /**
     * Delete a sandbox endpoint.
     */
    public function deleteSandboxEndpoint(string $endpointId): void
    {
        $this->doDelete("/api/v1/sandbox-endpoints/{$endpointId}");
    }

    /**
     * List requests received by a sandbox endpoint.
     */
    public function listSandboxRequests(string $endpointId, int $limit = 50): array
    {
        return $this->get("/api/v1/sandbox-endpoints/{$endpointId}/requests", ['limit' => $limit]);
    }

    // -------------------------------------------------------------------------
    // Analytics
    // -------------------------------------------------------------------------

    /**
     * Get events per day for the last N days.
     */
    public function eventsPerDay(int $days = 7): array
    {
        return $this->get('/api/v1/analytics/events-per-day', ['days' => $days]);
    }

    /**
     * Get deliveries per day for the last N days.
     */
    public function deliveriesPerDay(int $days = 7): array
    {
        return $this->get('/api/v1/analytics/deliveries-per-day', ['days' => $days]);
    }

    /**
     * Get top topics by event count.
     */
    public function topTopics(int $limit = 10): array
    {
        return $this->get('/api/v1/analytics/top-topics', ['limit' => $limit]);
    }

    /**
     * Get webhook delivery statistics.
     */
    public function webhookStats(): array
    {
        return $this->get('/api/v1/analytics/webhook-stats');
    }

    // -------------------------------------------------------------------------
    // Project (single / current)
    // -------------------------------------------------------------------------

    /**
     * Get current project details.
     */
    public function getProject(): array
    {
        return $this->get('/api/v1/project');
    }

    /**
     * Update current project.
     */
    public function updateProject(array $data): array
    {
        return $this->patch('/api/v1/project', $data);
    }

    /**
     * List all topics in the current project.
     */
    public function listTopics(): array
    {
        return $this->get('/api/v1/topics');
    }

    /**
     * Get the current API token info.
     */
    public function getToken(): array
    {
        return $this->get('/api/v1/token');
    }

    /**
     * Regenerate the API token.
     */
    public function regenerateToken(): array
    {
        return $this->post('/api/v1/token/regenerate', []);
    }

    // -------------------------------------------------------------------------
    // Projects (multi)
    // -------------------------------------------------------------------------

    /**
     * List all projects.
     */
    public function listProjects(): array
    {
        return $this->get('/api/v1/projects');
    }

    /**
     * Create a new project.
     */
    public function createProject(string $name): array
    {
        return $this->post('/api/v1/projects', ['name' => $name]);
    }

    /**
     * Get project by ID.
     */
    public function getProjectById(string $projectId): array
    {
        return $this->get("/api/v1/projects/{$projectId}");
    }

    /**
     * Update a project by ID.
     */
    public function updateProjectById(string $projectId, array $data): array
    {
        return $this->patch("/api/v1/projects/{$projectId}", $data);
    }

    /**
     * Delete a project.
     */
    public function deleteProject(string $projectId): void
    {
        $this->doDelete("/api/v1/projects/{$projectId}");
    }

    /**
     * Set a project as the default.
     */
    public function setDefaultProject(string $projectId): array
    {
        return $this->patch("/api/v1/projects/{$projectId}/default", []);
    }

    // -------------------------------------------------------------------------
    // Teams
    // -------------------------------------------------------------------------

    /**
     * List members of a project.
     */
    public function listMembers(string $projectId): array
    {
        return $this->get("/api/v1/projects/{$projectId}/members");
    }

    /**
     * Add a member to a project.
     */
    public function addMember(string $projectId, string $email, string $role = 'member'): array
    {
        return $this->post("/api/v1/projects/{$projectId}/members", [
            'email' => $email,
            'role' => $role,
        ]);
    }

    /**
     * Update a member's role.
     */
    public function updateMember(string $projectId, string $memberId, string $role): array
    {
        return $this->patch("/api/v1/projects/{$projectId}/members/{$memberId}", [
            'role' => $role,
        ]);
    }

    /**
     * Remove a member from a project.
     */
    public function removeMember(string $projectId, string $memberId): void
    {
        $this->doDelete("/api/v1/projects/{$projectId}/members/{$memberId}");
    }

    // -------------------------------------------------------------------------
    // Invitations
    // -------------------------------------------------------------------------

    /**
     * List pending invitations for the current user.
     */
    public function listPendingInvitations(): array
    {
        return $this->get('/api/v1/invitations/pending');
    }

    /**
     * Accept an invitation.
     */
    public function acceptInvitation(string $invitationId): array
    {
        return $this->post("/api/v1/invitations/{$invitationId}/accept", []);
    }

    /**
     * Reject an invitation.
     */
    public function rejectInvitation(string $invitationId): array
    {
        return $this->post("/api/v1/invitations/{$invitationId}/reject", []);
    }

    // -------------------------------------------------------------------------
    // Audit
    // -------------------------------------------------------------------------

    /**
     * List audit log entries.
     */
    public function listAuditLogs(int $limit = 50, ?string $cursor = null): array
    {
        return $this->get('/api/v1/audit-log', ['limit' => $limit, 'cursor' => $cursor]);
    }

    // -------------------------------------------------------------------------
    // Export
    // -------------------------------------------------------------------------

    /**
     * Export events as CSV or JSON. Returns raw string.
     */
    public function exportEvents(string $format = 'csv'): string
    {
        return $this->requestRaw('GET', '/api/v1/export/events', ['format' => $format]);
    }

    /**
     * Export deliveries as CSV or JSON. Returns raw string.
     */
    public function exportDeliveries(string $format = 'csv'): string
    {
        return $this->requestRaw('GET', '/api/v1/export/deliveries', ['format' => $format]);
    }

    /**
     * Export jobs as CSV or JSON. Returns raw string.
     */
    public function exportJobs(string $format = 'csv'): string
    {
        return $this->requestRaw('GET', '/api/v1/export/jobs', ['format' => $format]);
    }

    /**
     * Export audit log as CSV or JSON. Returns raw string.
     */
    public function exportAuditLog(string $format = 'csv'): string
    {
        return $this->requestRaw('GET', '/api/v1/export/audit-log', ['format' => $format]);
    }

    // -------------------------------------------------------------------------
    // GDPR
    // -------------------------------------------------------------------------

    /**
     * Get current user consent status.
     */
    public function getConsents(): array
    {
        return $this->get('/api/v1/me/consents');
    }

    /**
     * Accept consent for a specific purpose.
     */
    public function acceptConsent(string $purpose): array
    {
        return $this->post("/api/v1/me/consents/{$purpose}/accept", []);
    }

    /**
     * Export all personal data (GDPR data portability).
     */
    public function exportMyData(): array
    {
        return $this->get('/api/v1/me/data');
    }

    /**
     * Request restriction of data processing.
     */
    public function restrictProcessing(): array
    {
        return $this->post('/api/v1/me/restrict', []);
    }

    /**
     * Lift restriction on data processing.
     */
    public function liftRestriction(): void
    {
        $this->doDelete('/api/v1/me/restrict');
    }

    /**
     * Object to data processing.
     */
    public function objectToProcessing(): array
    {
        return $this->post('/api/v1/me/object', []);
    }

    /**
     * Withdraw objection to data processing.
     */
    public function restoreConsent(): void
    {
        $this->doDelete('/api/v1/me/object');
    }

    // -------------------------------------------------------------------------
    // Health
    // -------------------------------------------------------------------------

    /**
     * Check API health.
     */
    public function health(): array
    {
        return $this->get('/health');
    }

    /**
     * Get platform status page.
     */
    public function status(): array
    {
        return $this->get('/status');
    }

    // =========================================================================
    // Private HTTP helpers
    // =========================================================================

    private function get(string $path, array $params = []): array
    {
        return $this->request('GET', $path, params: $params);
    }

    private function post(string $path, array $body): array
    {
        return $this->request('POST', $path, body: $body);
    }

    private function patch(string $path, array $body): array
    {
        return $this->request('PATCH', $path, body: $body);
    }

    private function doDelete(string $path): void
    {
        $this->request('DELETE', $path);
    }

    /**
     * POST without X-Api-Key header (for public auth endpoints).
     */
    private function publicPost(string $path, array $body): array
    {
        $url = $this->baseUrl . $path;

        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => $this->timeout,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode($body),
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'Accept: application/json',
            ],
        ]);

        $response = curl_exec($ch);
        $statusCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);

        if ($curlError !== '') {
            throw new JobcelisException(0, "cURL error: {$curlError}");
        }

        if ($statusCode === 204) {
            return [];
        }

        if ($statusCode >= 400) {
            $detail = json_decode((string) $response, true);
            if ($detail === null) {
                $detail = (string) $response;
            }
            $errorMsg = is_array($detail) ? ($detail['error'] ?? $detail) : $detail;
            throw new JobcelisException($statusCode, $errorMsg);
        }

        return json_decode((string) $response, true) ?? [];
    }

    /**
     * Core request method using cURL.
     */
    private function request(string $method, string $path, array $params = [], ?array $body = null): array
    {
        $url = $this->baseUrl . $path;

        // Filter out null params and build query string
        $params = array_filter($params, fn ($v) => $v !== null);
        if (!empty($params)) {
            $url .= '?' . http_build_query($params);
        }

        $headers = [
            'Content-Type: application/json',
            'Accept: application/json',
            'X-Api-Key: ' . $this->apiKey,
        ];

        if ($this->authToken !== null) {
            $headers[] = 'Authorization: Bearer ' . $this->authToken;
        }

        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => $this->timeout,
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_HTTPHEADER => $headers,
        ]);

        if ($body !== null && in_array($method, ['POST', 'PATCH', 'PUT'], true)) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
        }

        $response = curl_exec($ch);
        $statusCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);

        if ($curlError !== '') {
            throw new JobcelisException(0, "cURL error: {$curlError}");
        }

        if ($statusCode === 204) {
            return [];
        }

        if ($statusCode >= 400) {
            $detail = json_decode((string) $response, true);
            if ($detail === null) {
                $detail = (string) $response;
            }
            $errorMsg = is_array($detail) ? ($detail['error'] ?? $detail) : $detail;
            throw new JobcelisException($statusCode, $errorMsg);
        }

        return json_decode((string) $response, true) ?? [];
    }

    /**
     * Like request() but returns the raw response body as a string.
     */
    private function requestRaw(string $method, string $path, array $params = []): string
    {
        $url = $this->baseUrl . $path;

        $params = array_filter($params, fn ($v) => $v !== null);
        if (!empty($params)) {
            $url .= '?' . http_build_query($params);
        }

        $headers = [
            'X-Api-Key: ' . $this->apiKey,
        ];

        if ($this->authToken !== null) {
            $headers[] = 'Authorization: Bearer ' . $this->authToken;
        }

        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => $this->timeout,
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_HTTPHEADER => $headers,
        ]);

        $response = curl_exec($ch);
        $statusCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);

        if ($curlError !== '') {
            throw new JobcelisException(0, "cURL error: {$curlError}");
        }

        if ($statusCode >= 400) {
            $detail = json_decode((string) $response, true);
            if ($detail === null) {
                $detail = (string) $response;
            }
            $errorMsg = is_array($detail) ? ($detail['error'] ?? $detail) : $detail;
            throw new JobcelisException($statusCode, $errorMsg);
        }

        return (string) $response;
    }
}
