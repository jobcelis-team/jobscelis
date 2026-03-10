using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Web;

namespace Jobcelis;

/// <summary>
/// Client for the Jobcelis Event Infrastructure Platform API.
/// All API calls go to https://jobcelis.com by default.
/// </summary>
public class JobcelisClient : IDisposable
{
    private readonly HttpClient _http;
    private readonly string _apiKey;
    private string? _authToken;
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    /// <summary>
    /// Create a new Jobcelis client.
    /// </summary>
    /// <param name="apiKey">Your Jobcelis API key.</param>
    /// <param name="baseUrl">Base URL of the Jobcelis API (default: https://jobcelis.com).</param>
    /// <param name="httpClient">Optional HttpClient to use (for testing/DI).</param>
    public JobcelisClient(string apiKey, string baseUrl = "https://jobcelis.com", HttpClient? httpClient = null)
    {
        _apiKey = apiKey;
        _http = httpClient ?? new HttpClient();
        _http.BaseAddress = new Uri(baseUrl.TrimEnd('/'));
    }

    /// <summary>Set JWT bearer token for authenticated requests.</summary>
    public void SetAuthToken(string token) => _authToken = token;

    // -------------------------------------------------------------------------
    // Auth
    // -------------------------------------------------------------------------

    /// <summary>Register a new account. Does not use API key auth.</summary>
    public Task<JsonElement> RegisterAsync(string email, string password, string? name = null)
    {
        var body = new Dictionary<string, object?> { ["email"] = email, ["password"] = password };
        if (name != null) body["name"] = name;
        return PublicPostAsync("/api/v1/auth/register", body);
    }

    /// <summary>Log in and receive JWT + refresh token.</summary>
    public Task<JsonElement> LoginAsync(string email, string password)
        => PublicPostAsync("/api/v1/auth/login", new { email, password });

    /// <summary>Refresh an expired JWT.</summary>
    public Task<JsonElement> RefreshTokenAsync(string refreshToken)
        => PublicPostAsync("/api/v1/auth/refresh", new { refresh_token = refreshToken });

    /// <summary>Verify MFA code.</summary>
    public Task<JsonElement> VerifyMfaAsync(string token, string code)
        => PostAsync("/api/v1/auth/mfa/verify", new { token, code });

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// <summary>Send a single event.</summary>
    public Task<JsonElement> SendEventAsync(string topic, object payload)
        => PostAsync("/api/v1/events", new { topic, payload });

    /// <summary>Send up to 1000 events in a batch.</summary>
    public Task<JsonElement> SendEventsAsync(IEnumerable<object> events)
        => PostAsync("/api/v1/events/batch", new { events });

    /// <summary>Get event details.</summary>
    public Task<JsonElement> GetEventAsync(string eventId)
        => GetAsync($"/api/v1/events/{eventId}");

    /// <summary>List events with cursor pagination.</summary>
    public Task<JsonElement> ListEventsAsync(int limit = 50, string? cursor = null)
        => GetAsync("/api/v1/events", new() { ["limit"] = limit.ToString(), ["cursor"] = cursor });

    /// <summary>Delete an event.</summary>
    public Task DeleteEventAsync(string eventId)
        => DoDeleteAsync($"/api/v1/events/{eventId}");

    // -------------------------------------------------------------------------
    // Simulate
    // -------------------------------------------------------------------------

    /// <summary>Simulate sending an event (dry run).</summary>
    public Task<JsonElement> SimulateEventAsync(string topic, object payload)
        => PostAsync("/api/v1/simulate", new { topic, payload });

    // -------------------------------------------------------------------------
    // Webhooks
    // -------------------------------------------------------------------------

    /// <summary>Create a webhook.</summary>
    public Task<JsonElement> CreateWebhookAsync(string url, Dictionary<string, object?>? extra = null)
    {
        var body = new Dictionary<string, object?> { ["url"] = url };
        if (extra != null) foreach (var kv in extra) body[kv.Key] = kv.Value;
        return PostAsync("/api/v1/webhooks", body);
    }

    /// <summary>Get webhook details.</summary>
    public Task<JsonElement> GetWebhookAsync(string webhookId)
        => GetAsync($"/api/v1/webhooks/{webhookId}");

    /// <summary>List webhooks.</summary>
    public Task<JsonElement> ListWebhooksAsync(int limit = 50, string? cursor = null)
        => GetAsync("/api/v1/webhooks", new() { ["limit"] = limit.ToString(), ["cursor"] = cursor });

    /// <summary>Update a webhook.</summary>
    public Task<JsonElement> UpdateWebhookAsync(string webhookId, object data)
        => PatchAsync($"/api/v1/webhooks/{webhookId}", data);

    /// <summary>Delete a webhook.</summary>
    public Task DeleteWebhookAsync(string webhookId)
        => DoDeleteAsync($"/api/v1/webhooks/{webhookId}");

    /// <summary>Get health status for a webhook.</summary>
    public Task<JsonElement> WebhookHealthAsync(string webhookId)
        => GetAsync($"/api/v1/webhooks/{webhookId}/health");

    /// <summary>List available webhook templates.</summary>
    public Task<JsonElement> WebhookTemplatesAsync()
        => GetAsync("/api/v1/webhooks/templates");

    // -------------------------------------------------------------------------
    // Deliveries
    // -------------------------------------------------------------------------

    /// <summary>List deliveries.</summary>
    public Task<JsonElement> ListDeliveriesAsync(int limit = 50, string? cursor = null, string? status = null)
        => GetAsync("/api/v1/deliveries", new() { ["limit"] = limit.ToString(), ["cursor"] = cursor, ["status"] = status });

    /// <summary>Retry a failed delivery.</summary>
    public Task<JsonElement> RetryDeliveryAsync(string deliveryId)
        => PostAsync($"/api/v1/deliveries/{deliveryId}/retry", new { });

    // -------------------------------------------------------------------------
    // Dead Letters
    // -------------------------------------------------------------------------

    /// <summary>List dead letters.</summary>
    public Task<JsonElement> ListDeadLettersAsync(int limit = 50, string? cursor = null)
        => GetAsync("/api/v1/dead-letters", new() { ["limit"] = limit.ToString(), ["cursor"] = cursor });

    /// <summary>Get dead letter details.</summary>
    public Task<JsonElement> GetDeadLetterAsync(string deadLetterId)
        => GetAsync($"/api/v1/dead-letters/{deadLetterId}");

    /// <summary>Retry a dead letter.</summary>
    public Task<JsonElement> RetryDeadLetterAsync(string deadLetterId)
        => PostAsync($"/api/v1/dead-letters/{deadLetterId}/retry", new { });

    /// <summary>Mark a dead letter as resolved.</summary>
    public Task<JsonElement> ResolveDeadLetterAsync(string deadLetterId)
        => PatchAsync($"/api/v1/dead-letters/{deadLetterId}/resolve", new { });

    // -------------------------------------------------------------------------
    // Replays
    // -------------------------------------------------------------------------

    /// <summary>Start an event replay.</summary>
    public Task<JsonElement> CreateReplayAsync(string topic, string fromDate, string toDate, string? webhookId = null)
    {
        var body = new Dictionary<string, object?> { ["topic"] = topic, ["from_date"] = fromDate, ["to_date"] = toDate };
        if (webhookId != null) body["webhook_id"] = webhookId;
        return PostAsync("/api/v1/replays", body);
    }

    /// <summary>List replays.</summary>
    public Task<JsonElement> ListReplaysAsync(int limit = 50, string? cursor = null)
        => GetAsync("/api/v1/replays", new() { ["limit"] = limit.ToString(), ["cursor"] = cursor });

    /// <summary>Get replay details.</summary>
    public Task<JsonElement> GetReplayAsync(string replayId)
        => GetAsync($"/api/v1/replays/{replayId}");

    /// <summary>Cancel a replay.</summary>
    public Task CancelReplayAsync(string replayId)
        => DoDeleteAsync($"/api/v1/replays/{replayId}");

    // -------------------------------------------------------------------------
    // Jobs
    // -------------------------------------------------------------------------

    /// <summary>Create a scheduled job.</summary>
    public Task<JsonElement> CreateJobAsync(string name, string queue, string cronExpression, Dictionary<string, object?>? extra = null)
    {
        var body = new Dictionary<string, object?> { ["name"] = name, ["queue"] = queue, ["cron_expression"] = cronExpression };
        if (extra != null) foreach (var kv in extra) body[kv.Key] = kv.Value;
        return PostAsync("/api/v1/jobs", body);
    }

    /// <summary>List scheduled jobs.</summary>
    public Task<JsonElement> ListJobsAsync(int limit = 50, string? cursor = null)
        => GetAsync("/api/v1/jobs", new() { ["limit"] = limit.ToString(), ["cursor"] = cursor });

    /// <summary>Get job details.</summary>
    public Task<JsonElement> GetJobAsync(string jobId)
        => GetAsync($"/api/v1/jobs/{jobId}");

    /// <summary>Update a scheduled job.</summary>
    public Task<JsonElement> UpdateJobAsync(string jobId, object data)
        => PatchAsync($"/api/v1/jobs/{jobId}", data);

    /// <summary>Delete a scheduled job.</summary>
    public Task DeleteJobAsync(string jobId)
        => DoDeleteAsync($"/api/v1/jobs/{jobId}");

    /// <summary>List runs for a scheduled job.</summary>
    public Task<JsonElement> ListJobRunsAsync(string jobId, int limit = 50)
        => GetAsync($"/api/v1/jobs/{jobId}/runs", new() { ["limit"] = limit.ToString() });

    /// <summary>Preview next occurrences for a cron expression.</summary>
    public Task<JsonElement> CronPreviewAsync(string expression, int count = 5)
        => GetAsync("/api/v1/jobs/cron-preview", new() { ["expression"] = expression, ["count"] = count.ToString() });

    // -------------------------------------------------------------------------
    // Pipelines
    // -------------------------------------------------------------------------

    /// <summary>Create an event pipeline.</summary>
    public Task<JsonElement> CreatePipelineAsync(string name, IEnumerable<string> topics, IEnumerable<object> steps)
        => PostAsync("/api/v1/pipelines", new { name, topics, steps });

    /// <summary>List pipelines.</summary>
    public Task<JsonElement> ListPipelinesAsync(int limit = 50, string? cursor = null)
        => GetAsync("/api/v1/pipelines", new() { ["limit"] = limit.ToString(), ["cursor"] = cursor });

    /// <summary>Get pipeline details.</summary>
    public Task<JsonElement> GetPipelineAsync(string pipelineId)
        => GetAsync($"/api/v1/pipelines/{pipelineId}");

    /// <summary>Update a pipeline.</summary>
    public Task<JsonElement> UpdatePipelineAsync(string pipelineId, object data)
        => PatchAsync($"/api/v1/pipelines/{pipelineId}", data);

    /// <summary>Delete a pipeline.</summary>
    public Task DeletePipelineAsync(string pipelineId)
        => DoDeleteAsync($"/api/v1/pipelines/{pipelineId}");

    /// <summary>Test a pipeline with a sample payload.</summary>
    public Task<JsonElement> TestPipelineAsync(string pipelineId, object payload)
        => PostAsync($"/api/v1/pipelines/{pipelineId}/test", payload);

    // -------------------------------------------------------------------------
    // Event Schemas
    // -------------------------------------------------------------------------

    /// <summary>Create an event schema.</summary>
    public Task<JsonElement> CreateEventSchemaAsync(string topic, object schema)
        => PostAsync("/api/v1/event-schemas", new { topic, schema });

    /// <summary>List event schemas.</summary>
    public Task<JsonElement> ListEventSchemasAsync(int limit = 50, string? cursor = null)
        => GetAsync("/api/v1/event-schemas", new() { ["limit"] = limit.ToString(), ["cursor"] = cursor });

    /// <summary>Get event schema details.</summary>
    public Task<JsonElement> GetEventSchemaAsync(string schemaId)
        => GetAsync($"/api/v1/event-schemas/{schemaId}");

    /// <summary>Update an event schema.</summary>
    public Task<JsonElement> UpdateEventSchemaAsync(string schemaId, object data)
        => PatchAsync($"/api/v1/event-schemas/{schemaId}", data);

    /// <summary>Delete an event schema.</summary>
    public Task DeleteEventSchemaAsync(string schemaId)
        => DoDeleteAsync($"/api/v1/event-schemas/{schemaId}");

    /// <summary>Validate a payload against the schema for a topic.</summary>
    public Task<JsonElement> ValidatePayloadAsync(string topic, object payload)
        => PostAsync("/api/v1/event-schemas/validate", new { topic, payload });

    // -------------------------------------------------------------------------
    // Sandbox
    // -------------------------------------------------------------------------

    /// <summary>List sandbox endpoints.</summary>
    public Task<JsonElement> ListSandboxEndpointsAsync()
        => GetAsync("/api/v1/sandbox-endpoints");

    /// <summary>Create a sandbox endpoint.</summary>
    public Task<JsonElement> CreateSandboxEndpointAsync(string? name = null)
    {
        var body = name != null ? new Dictionary<string, object?> { ["name"] = name } : new Dictionary<string, object?>();
        return PostAsync("/api/v1/sandbox-endpoints", body);
    }

    /// <summary>Delete a sandbox endpoint.</summary>
    public Task DeleteSandboxEndpointAsync(string endpointId)
        => DoDeleteAsync($"/api/v1/sandbox-endpoints/{endpointId}");

    /// <summary>List requests received by a sandbox endpoint.</summary>
    public Task<JsonElement> ListSandboxRequestsAsync(string endpointId, int limit = 50)
        => GetAsync($"/api/v1/sandbox-endpoints/{endpointId}/requests", new() { ["limit"] = limit.ToString() });

    // -------------------------------------------------------------------------
    // Analytics
    // -------------------------------------------------------------------------

    /// <summary>Get events per day for the last N days.</summary>
    public Task<JsonElement> EventsPerDayAsync(int days = 7)
        => GetAsync("/api/v1/analytics/events-per-day", new() { ["days"] = days.ToString() });

    /// <summary>Get deliveries per day for the last N days.</summary>
    public Task<JsonElement> DeliveriesPerDayAsync(int days = 7)
        => GetAsync("/api/v1/analytics/deliveries-per-day", new() { ["days"] = days.ToString() });

    /// <summary>Get top topics by event count.</summary>
    public Task<JsonElement> TopTopicsAsync(int limit = 10)
        => GetAsync("/api/v1/analytics/top-topics", new() { ["limit"] = limit.ToString() });

    /// <summary>Get webhook delivery statistics.</summary>
    public Task<JsonElement> WebhookStatsAsync()
        => GetAsync("/api/v1/analytics/webhook-stats");

    // -------------------------------------------------------------------------
    // Project (current)
    // -------------------------------------------------------------------------

    /// <summary>Get current project details.</summary>
    public Task<JsonElement> GetProjectAsync()
        => GetAsync("/api/v1/project");

    /// <summary>Update current project.</summary>
    public Task<JsonElement> UpdateProjectAsync(object data)
        => PatchAsync("/api/v1/project", data);

    /// <summary>List all topics in the current project.</summary>
    public Task<JsonElement> ListTopicsAsync()
        => GetAsync("/api/v1/topics");

    /// <summary>Get the current API token info.</summary>
    public Task<JsonElement> GetTokenAsync()
        => GetAsync("/api/v1/token");

    /// <summary>Regenerate the API token.</summary>
    public Task<JsonElement> RegenerateTokenAsync()
        => PostAsync("/api/v1/token/regenerate", new { });

    // -------------------------------------------------------------------------
    // Projects (multi)
    // -------------------------------------------------------------------------

    /// <summary>List all projects.</summary>
    public Task<JsonElement> ListProjectsAsync()
        => GetAsync("/api/v1/projects");

    /// <summary>Create a new project.</summary>
    public Task<JsonElement> CreateProjectAsync(string name)
        => PostAsync("/api/v1/projects", new { name });

    /// <summary>Get project by ID.</summary>
    public Task<JsonElement> GetProjectByIdAsync(string projectId)
        => GetAsync($"/api/v1/projects/{projectId}");

    /// <summary>Update a project by ID.</summary>
    public Task<JsonElement> UpdateProjectByIdAsync(string projectId, object data)
        => PatchAsync($"/api/v1/projects/{projectId}", data);

    /// <summary>Delete a project.</summary>
    public Task DeleteProjectAsync(string projectId)
        => DoDeleteAsync($"/api/v1/projects/{projectId}");

    /// <summary>Set a project as the default.</summary>
    public Task<JsonElement> SetDefaultProjectAsync(string projectId)
        => PatchAsync($"/api/v1/projects/{projectId}/default", new { });

    // -------------------------------------------------------------------------
    // Teams
    // -------------------------------------------------------------------------

    /// <summary>List members of a project.</summary>
    public Task<JsonElement> ListMembersAsync(string projectId)
        => GetAsync($"/api/v1/projects/{projectId}/members");

    /// <summary>Add a member to a project.</summary>
    public Task<JsonElement> AddMemberAsync(string projectId, string email, string role = "member")
        => PostAsync($"/api/v1/projects/{projectId}/members", new { email, role });

    /// <summary>Update a member's role.</summary>
    public Task<JsonElement> UpdateMemberAsync(string projectId, string memberId, string role)
        => PatchAsync($"/api/v1/projects/{projectId}/members/{memberId}", new { role });

    /// <summary>Remove a member from a project.</summary>
    public Task RemoveMemberAsync(string projectId, string memberId)
        => DoDeleteAsync($"/api/v1/projects/{projectId}/members/{memberId}");

    // -------------------------------------------------------------------------
    // Invitations
    // -------------------------------------------------------------------------

    /// <summary>List pending invitations for the current user.</summary>
    public Task<JsonElement> ListPendingInvitationsAsync()
        => GetAsync("/api/v1/invitations/pending");

    /// <summary>Accept an invitation.</summary>
    public Task<JsonElement> AcceptInvitationAsync(string invitationId)
        => PostAsync($"/api/v1/invitations/{invitationId}/accept", new { });

    /// <summary>Reject an invitation.</summary>
    public Task<JsonElement> RejectInvitationAsync(string invitationId)
        => PostAsync($"/api/v1/invitations/{invitationId}/reject", new { });

    // -------------------------------------------------------------------------
    // Audit
    // -------------------------------------------------------------------------

    /// <summary>List audit log entries.</summary>
    public Task<JsonElement> ListAuditLogsAsync(int limit = 50, string? cursor = null)
        => GetAsync("/api/v1/audit-log", new() { ["limit"] = limit.ToString(), ["cursor"] = cursor });

    // -------------------------------------------------------------------------
    // Export
    // -------------------------------------------------------------------------

    /// <summary>Export events as CSV or JSON. Returns raw string.</summary>
    public Task<string> ExportEventsAsync(string format = "csv")
        => GetRawAsync("/api/v1/export/events", new() { ["format"] = format });

    /// <summary>Export deliveries as CSV or JSON. Returns raw string.</summary>
    public Task<string> ExportDeliveriesAsync(string format = "csv")
        => GetRawAsync("/api/v1/export/deliveries", new() { ["format"] = format });

    /// <summary>Export jobs as CSV or JSON. Returns raw string.</summary>
    public Task<string> ExportJobsAsync(string format = "csv")
        => GetRawAsync("/api/v1/export/jobs", new() { ["format"] = format });

    /// <summary>Export audit log as CSV or JSON. Returns raw string.</summary>
    public Task<string> ExportAuditLogAsync(string format = "csv")
        => GetRawAsync("/api/v1/export/audit-log", new() { ["format"] = format });

    // -------------------------------------------------------------------------
    // GDPR
    // -------------------------------------------------------------------------

    /// <summary>Get current user consent status.</summary>
    public Task<JsonElement> GetConsentsAsync()
        => GetAsync("/api/v1/me/consents");

    /// <summary>Accept consent for a specific purpose.</summary>
    public Task<JsonElement> AcceptConsentAsync(string purpose)
        => PostAsync($"/api/v1/me/consents/{purpose}/accept", new { });

    /// <summary>Export all personal data (GDPR data portability).</summary>
    public Task<JsonElement> ExportMyDataAsync()
        => GetAsync("/api/v1/me/data");

    /// <summary>Request restriction of data processing.</summary>
    public Task<JsonElement> RestrictProcessingAsync()
        => PostAsync("/api/v1/me/restrict", new { });

    /// <summary>Lift restriction on data processing.</summary>
    public Task LiftRestrictionAsync()
        => DoDeleteAsync("/api/v1/me/restrict");

    /// <summary>Object to data processing.</summary>
    public Task<JsonElement> ObjectToProcessingAsync()
        => PostAsync("/api/v1/me/object", new { });

    /// <summary>Withdraw objection to data processing.</summary>
    public Task RestoreConsentAsync()
        => DoDeleteAsync("/api/v1/me/object");

    // -------------------------------------------------------------------------
    // Health
    // -------------------------------------------------------------------------

    /// <summary>Check API health.</summary>
    public Task<JsonElement> HealthAsync()
        => GetAsync("/health");

    /// <summary>Get platform status.</summary>
    public Task<JsonElement> StatusAsync()
        => GetAsync("/status");

    // -------------------------------------------------------------------------
    // Embed Tokens
    // -------------------------------------------------------------------------

    /// <summary>List embed tokens.</summary>
    public Task<JsonElement> ListEmbedTokensAsync()
        => GetAsync("/api/v1/embed/tokens");

    /// <summary>Create an embed token.</summary>
    public Task<JsonElement> CreateEmbedTokenAsync(object config)
        => PostAsync("/api/v1/embed/tokens", config);

    /// <summary>Revoke an embed token.</summary>
    public Task RevokeEmbedTokenAsync(string id)
        => DoDeleteAsync($"/api/v1/embed/tokens/{id}");

    // -------------------------------------------------------------------------
    // Notification Channels
    // -------------------------------------------------------------------------

    /// <summary>Get the notification channel configuration.</summary>
    public Task<JsonElement> GetNotificationChannelAsync()
        => GetAsync("/api/v1/notification-channels");

    /// <summary>Create or update the notification channel configuration.</summary>
    public Task<JsonElement> UpsertNotificationChannelAsync(object config)
        => PutAsync("/api/v1/notification-channels", config);

    /// <summary>Delete the notification channel configuration.</summary>
    public Task DeleteNotificationChannelAsync()
        => DoDeleteAsync("/api/v1/notification-channels");

    /// <summary>Test the notification channel configuration.</summary>
    public Task<JsonElement> TestNotificationChannelAsync()
        => PostAsync("/api/v1/notification-channels/test", new { });

    // =========================================================================
    // Private HTTP helpers
    // =========================================================================

    private Task<JsonElement> GetAsync(string path, Dictionary<string, string?>? parameters = null)
        => RequestAsync(HttpMethod.Get, path, parameters: parameters);

    private Task<JsonElement> PostAsync(string path, object body)
        => RequestAsync(HttpMethod.Post, path, body: body);

    private Task<JsonElement> PatchAsync(string path, object body)
        => RequestAsync(HttpMethod.Patch, path, body: body);

    private Task<JsonElement> PutAsync(string path, object body)
        => RequestAsync(HttpMethod.Put, path, body: body);

    private Task DoDeleteAsync(string path)
        => RequestAsync(HttpMethod.Delete, path).ContinueWith(_ => { });

    private Task<string> GetRawAsync(string path, Dictionary<string, string?>? parameters = null)
        => RequestRawAsync(HttpMethod.Get, path, parameters);

    private Task<JsonElement> PublicPostAsync(string path, object body)
    {
        var json = JsonSerializer.Serialize(body, JsonOpts);
        var content = new StringContent(json, Encoding.UTF8, "application/json");
        return SendAsync(HttpMethod.Post, path, content, useApiKey: false);
    }

    private async Task<JsonElement> RequestAsync(HttpMethod method, string path,
        Dictionary<string, string?>? parameters = null, object? body = null)
    {
        var url = BuildUrl(path, parameters);
        HttpContent? content = null;
        if (body != null)
        {
            var json = JsonSerializer.Serialize(body, JsonOpts);
            content = new StringContent(json, Encoding.UTF8, "application/json");
        }
        return await SendAsync(method, url, content, useApiKey: true);
    }

    private async Task<string> RequestRawAsync(HttpMethod method, string path,
        Dictionary<string, string?>? parameters = null)
    {
        var url = BuildUrl(path, parameters);
        using var request = new HttpRequestMessage(method, url);
        request.Headers.Add("X-Api-Key", _apiKey);
        if (_authToken != null) request.Headers.Add("Authorization", $"Bearer {_authToken}");

        var response = await _http.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            object? detail;
            try { detail = JsonSerializer.Deserialize<JsonElement>(responseBody); }
            catch { detail = responseBody; }
            throw new JobcelisException((int)response.StatusCode, detail);
        }

        return responseBody;
    }

    private async Task<JsonElement> SendAsync(HttpMethod method, string url, HttpContent? content, bool useApiKey)
    {
        using var request = new HttpRequestMessage(method, url);
        request.Headers.Add("Accept", "application/json");
        if (useApiKey) request.Headers.Add("X-Api-Key", _apiKey);
        if (_authToken != null) request.Headers.Add("Authorization", $"Bearer {_authToken}");
        if (content != null) request.Content = content;

        var response = await _http.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();

        if (response.StatusCode == System.Net.HttpStatusCode.NoContent)
            return default;

        if (!response.IsSuccessStatusCode)
        {
            object? detail;
            try { detail = JsonSerializer.Deserialize<JsonElement>(responseBody); }
            catch { detail = responseBody; }
            throw new JobcelisException((int)response.StatusCode, detail);
        }

        return JsonSerializer.Deserialize<JsonElement>(responseBody);
    }

    private static string BuildUrl(string path, Dictionary<string, string?>? parameters)
    {
        if (parameters == null || parameters.Count == 0) return path;

        var filtered = parameters.Where(kv => kv.Value != null);
        if (!filtered.Any()) return path;

        var query = string.Join("&", filtered.Select(kv =>
            $"{HttpUtility.UrlEncode(kv.Key)}={HttpUtility.UrlEncode(kv.Value)}"));
        return $"{path}?{query}";
    }

    /// <inheritdoc/>
    public void Dispose()
    {
        _http.Dispose();
        GC.SuppressFinalize(this);
    }
}
