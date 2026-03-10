import 'dart:convert';
import 'package:http/http.dart' as http;
import 'exception.dart';

/// Client for the Jobcelis Event Infrastructure Platform API.
///
/// All API calls go to `https://jobcelis.com` by default.
///
/// ```dart
/// final client = JobcelisClient(apiKey: 'your_api_key');
/// final event = await client.sendEvent('order.created', {'order_id': '123'});
/// ```
class JobcelisClient {
  final String _apiKey;
  final String _baseURL;
  final http.Client _httpClient;
  String? _authToken;

  /// Create a new Jobcelis client.
  ///
  /// [apiKey] - Your Jobcelis API key.
  /// [baseURL] - Base URL of the Jobcelis API (default: `https://jobcelis.com`).
  /// [httpClient] - Optional HTTP client (useful for testing).
  JobcelisClient({
    required String apiKey,
    String baseURL = 'https://jobcelis.com',
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _baseURL = baseURL.endsWith('/') ? baseURL.substring(0, baseURL.length - 1) : baseURL,
        _httpClient = httpClient ?? http.Client();

  /// Set JWT bearer token for authenticated requests.
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Close the underlying HTTP client.
  void close() {
    _httpClient.close();
  }

  // ── Auth ──────────────────────────────────────────────────────────────

  /// Register a new account. Does not use API key auth.
  Future<Map<String, dynamic>> register(String email, String password, {String? name}) async {
    final body = <String, dynamic>{'email': email, 'password': password};
    if (name != null) body['name'] = name;
    return _publicPost('/api/v1/auth/register', body);
  }

  /// Log in and receive JWT + refresh token.
  Future<Map<String, dynamic>> login(String email, String password) async {
    return _publicPost('/api/v1/auth/login', {'email': email, 'password': password});
  }

  /// Refresh an expired JWT.
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    return _publicPost('/api/v1/auth/refresh', {'refresh_token': refreshToken});
  }

  /// Verify MFA code.
  Future<Map<String, dynamic>> verifyMfa(String token, String code) async {
    return _post('/api/v1/auth/mfa/verify', {'token': token, 'code': code});
  }

  // ── Events ────────────────────────────────────────────────────────────

  /// Send a single event.
  Future<Map<String, dynamic>> sendEvent(String topic, Map<String, dynamic> payload) async {
    return _post('/api/v1/events', {'topic': topic, 'payload': payload});
  }

  /// Send up to 1000 events in a batch.
  Future<Map<String, dynamic>> sendEvents(List<Map<String, dynamic>> events) async {
    return _post('/api/v1/events/batch', {'events': events});
  }

  /// Get event details.
  Future<Map<String, dynamic>> getEvent(String eventId) async {
    return _get('/api/v1/events/$eventId');
  }

  /// List events with cursor pagination.
  Future<Map<String, dynamic>> listEvents({int limit = 50, String? cursor}) async {
    return _get('/api/v1/events', params: {'limit': '$limit', if (cursor != null) 'cursor': cursor});
  }

  /// Delete an event.
  Future<void> deleteEvent(String eventId) async {
    await _delete('/api/v1/events/$eventId');
  }

  // ── Simulate ──────────────────────────────────────────────────────────

  /// Simulate sending an event (dry run).
  Future<Map<String, dynamic>> simulateEvent(String topic, Map<String, dynamic> payload) async {
    return _post('/api/v1/simulate', {'topic': topic, 'payload': payload});
  }

  // ── Webhooks ──────────────────────────────────────────────────────────

  /// Create a webhook.
  ///
  /// [rateLimit] - Optional rate limiting configuration with keys
  /// `max_per_second` and/or `max_per_minute`.
  Future<Map<String, dynamic>> createWebhook(String url, {Map<String, dynamic>? extra, Map<String, dynamic>? rateLimit}) async {
    final body = <String, dynamic>{'url': url};
    if (extra != null) body.addAll(extra);
    if (rateLimit != null) body['rate_limit'] = rateLimit;
    return _post('/api/v1/webhooks', body);
  }

  /// Get webhook details.
  Future<Map<String, dynamic>> getWebhook(String webhookId) async {
    return _get('/api/v1/webhooks/$webhookId');
  }

  /// List webhooks.
  Future<Map<String, dynamic>> listWebhooks({int limit = 50, String? cursor}) async {
    return _get('/api/v1/webhooks', params: {'limit': '$limit', if (cursor != null) 'cursor': cursor});
  }

  /// Update a webhook.
  ///
  /// [rateLimit] - Optional rate limiting configuration with keys
  /// `max_per_second` and/or `max_per_minute`.
  Future<Map<String, dynamic>> updateWebhook(String webhookId, Map<String, dynamic> data, {Map<String, dynamic>? rateLimit}) async {
    if (rateLimit != null) data['rate_limit'] = rateLimit;
    return _patch('/api/v1/webhooks/$webhookId', data);
  }

  /// Delete a webhook.
  Future<void> deleteWebhook(String webhookId) async {
    await _delete('/api/v1/webhooks/$webhookId');
  }

  /// Get health status for a webhook.
  Future<Map<String, dynamic>> webhookHealth(String webhookId) async {
    return _get('/api/v1/webhooks/$webhookId/health');
  }

  /// List available webhook templates.
  Future<Map<String, dynamic>> webhookTemplates() async {
    return _get('/api/v1/webhooks/templates');
  }

  // ── Deliveries ────────────────────────────────────────────────────────

  /// List deliveries.
  Future<Map<String, dynamic>> listDeliveries({int limit = 50, String? cursor, String? status}) async {
    return _get('/api/v1/deliveries', params: {
      'limit': '$limit',
      if (cursor != null) 'cursor': cursor,
      if (status != null) 'status': status,
    });
  }

  /// Retry a failed delivery.
  Future<Map<String, dynamic>> retryDelivery(String deliveryId) async {
    return _post('/api/v1/deliveries/$deliveryId/retry', {});
  }

  // ── Dead Letters ──────────────────────────────────────────────────────

  /// List dead letters.
  Future<Map<String, dynamic>> listDeadLetters({int limit = 50, String? cursor}) async {
    return _get('/api/v1/dead-letters', params: {'limit': '$limit', if (cursor != null) 'cursor': cursor});
  }

  /// Get dead letter details.
  Future<Map<String, dynamic>> getDeadLetter(String deadLetterId) async {
    return _get('/api/v1/dead-letters/$deadLetterId');
  }

  /// Retry a dead letter.
  Future<Map<String, dynamic>> retryDeadLetter(String deadLetterId) async {
    return _post('/api/v1/dead-letters/$deadLetterId/retry', {});
  }

  /// Mark a dead letter as resolved.
  Future<Map<String, dynamic>> resolveDeadLetter(String deadLetterId) async {
    return _patch('/api/v1/dead-letters/$deadLetterId/resolve', {});
  }

  // ── Replays ───────────────────────────────────────────────────────────

  /// Start an event replay.
  Future<Map<String, dynamic>> createReplay(String topic, String fromDate, String toDate, {String? webhookId}) async {
    final body = <String, dynamic>{'topic': topic, 'from_date': fromDate, 'to_date': toDate};
    if (webhookId != null) body['webhook_id'] = webhookId;
    return _post('/api/v1/replays', body);
  }

  /// List replays.
  Future<Map<String, dynamic>> listReplays({int limit = 50, String? cursor}) async {
    return _get('/api/v1/replays', params: {'limit': '$limit', if (cursor != null) 'cursor': cursor});
  }

  /// Get replay details.
  Future<Map<String, dynamic>> getReplay(String replayId) async {
    return _get('/api/v1/replays/$replayId');
  }

  /// Cancel a replay.
  Future<void> cancelReplay(String replayId) async {
    await _delete('/api/v1/replays/$replayId');
  }

  // ── Jobs ──────────────────────────────────────────────────────────────

  /// Create a scheduled job.
  Future<Map<String, dynamic>> createJob(String name, String queue, String cronExpression, {Map<String, dynamic>? extra}) async {
    final body = <String, dynamic>{'name': name, 'queue': queue, 'cron_expression': cronExpression};
    if (extra != null) body.addAll(extra);
    return _post('/api/v1/jobs', body);
  }

  /// List scheduled jobs.
  Future<Map<String, dynamic>> listJobs({int limit = 50, String? cursor}) async {
    return _get('/api/v1/jobs', params: {'limit': '$limit', if (cursor != null) 'cursor': cursor});
  }

  /// Get job details.
  Future<Map<String, dynamic>> getJob(String jobId) async {
    return _get('/api/v1/jobs/$jobId');
  }

  /// Update a scheduled job.
  Future<Map<String, dynamic>> updateJob(String jobId, Map<String, dynamic> data) async {
    return _patch('/api/v1/jobs/$jobId', data);
  }

  /// Delete a scheduled job.
  Future<void> deleteJob(String jobId) async {
    await _delete('/api/v1/jobs/$jobId');
  }

  /// List runs for a scheduled job.
  Future<Map<String, dynamic>> listJobRuns(String jobId, {int limit = 50}) async {
    return _get('/api/v1/jobs/$jobId/runs', params: {'limit': '$limit'});
  }

  /// Preview next occurrences for a cron expression.
  Future<Map<String, dynamic>> cronPreview(String expression, {int count = 5}) async {
    return _get('/api/v1/jobs/cron-preview', params: {'expression': expression, 'count': '$count'});
  }

  // ── Pipelines ─────────────────────────────────────────────────────────

  /// Create an event pipeline.
  Future<Map<String, dynamic>> createPipeline(String name, List<String> topics, List<Map<String, dynamic>> steps) async {
    return _post('/api/v1/pipelines', {'name': name, 'topics': topics, 'steps': steps});
  }

  /// List pipelines.
  Future<Map<String, dynamic>> listPipelines({int limit = 50, String? cursor}) async {
    return _get('/api/v1/pipelines', params: {'limit': '$limit', if (cursor != null) 'cursor': cursor});
  }

  /// Get pipeline details.
  Future<Map<String, dynamic>> getPipeline(String pipelineId) async {
    return _get('/api/v1/pipelines/$pipelineId');
  }

  /// Update a pipeline.
  Future<Map<String, dynamic>> updatePipeline(String pipelineId, Map<String, dynamic> data) async {
    return _patch('/api/v1/pipelines/$pipelineId', data);
  }

  /// Delete a pipeline.
  Future<void> deletePipeline(String pipelineId) async {
    await _delete('/api/v1/pipelines/$pipelineId');
  }

  /// Test a pipeline with a sample payload.
  Future<Map<String, dynamic>> testPipeline(String pipelineId, Map<String, dynamic> payload) async {
    return _post('/api/v1/pipelines/$pipelineId/test', payload);
  }

  // ── Event Schemas ─────────────────────────────────────────────────────

  /// Create an event schema.
  Future<Map<String, dynamic>> createEventSchema(String topic, Map<String, dynamic> schema) async {
    return _post('/api/v1/event-schemas', {'topic': topic, 'schema': schema});
  }

  /// List event schemas.
  Future<Map<String, dynamic>> listEventSchemas({int limit = 50, String? cursor}) async {
    return _get('/api/v1/event-schemas', params: {'limit': '$limit', if (cursor != null) 'cursor': cursor});
  }

  /// Get event schema details.
  Future<Map<String, dynamic>> getEventSchema(String schemaId) async {
    return _get('/api/v1/event-schemas/$schemaId');
  }

  /// Update an event schema.
  Future<Map<String, dynamic>> updateEventSchema(String schemaId, Map<String, dynamic> data) async {
    return _patch('/api/v1/event-schemas/$schemaId', data);
  }

  /// Delete an event schema.
  Future<void> deleteEventSchema(String schemaId) async {
    await _delete('/api/v1/event-schemas/$schemaId');
  }

  /// Validate a payload against the schema for a topic.
  Future<Map<String, dynamic>> validatePayload(String topic, Map<String, dynamic> payload) async {
    return _post('/api/v1/event-schemas/validate', {'topic': topic, 'payload': payload});
  }

  // ── Sandbox ───────────────────────────────────────────────────────────

  /// List sandbox endpoints.
  Future<Map<String, dynamic>> listSandboxEndpoints() async {
    return _get('/api/v1/sandbox-endpoints');
  }

  /// Create a sandbox endpoint.
  Future<Map<String, dynamic>> createSandboxEndpoint({String? name}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    return _post('/api/v1/sandbox-endpoints', body);
  }

  /// Delete a sandbox endpoint.
  Future<void> deleteSandboxEndpoint(String endpointId) async {
    await _delete('/api/v1/sandbox-endpoints/$endpointId');
  }

  /// List requests received by a sandbox endpoint.
  Future<Map<String, dynamic>> listSandboxRequests(String endpointId, {int limit = 50}) async {
    return _get('/api/v1/sandbox-endpoints/$endpointId/requests', params: {'limit': '$limit'});
  }

  // ── Analytics ─────────────────────────────────────────────────────────

  /// Get events per day for the last N days.
  Future<Map<String, dynamic>> eventsPerDay({int days = 7}) async {
    return _get('/api/v1/analytics/events-per-day', params: {'days': '$days'});
  }

  /// Get deliveries per day for the last N days.
  Future<Map<String, dynamic>> deliveriesPerDay({int days = 7}) async {
    return _get('/api/v1/analytics/deliveries-per-day', params: {'days': '$days'});
  }

  /// Get top topics by event count.
  Future<Map<String, dynamic>> topTopics({int limit = 10}) async {
    return _get('/api/v1/analytics/top-topics', params: {'limit': '$limit'});
  }

  /// Get webhook delivery statistics.
  Future<Map<String, dynamic>> webhookStats() async {
    return _get('/api/v1/analytics/webhook-stats');
  }

  // ── Project (current) ─────────────────────────────────────────────────

  /// Get current project details.
  Future<Map<String, dynamic>> getProject() async {
    return _get('/api/v1/project');
  }

  /// Update current project.
  Future<Map<String, dynamic>> updateProject(Map<String, dynamic> data) async {
    return _patch('/api/v1/project', data);
  }

  /// List all topics in the current project.
  Future<Map<String, dynamic>> listTopics() async {
    return _get('/api/v1/topics');
  }

  /// Get the current API token info.
  Future<Map<String, dynamic>> getToken() async {
    return _get('/api/v1/token');
  }

  /// Regenerate the API token.
  Future<Map<String, dynamic>> regenerateToken() async {
    return _post('/api/v1/token/regenerate', {});
  }

  // ── Projects (multi) ──────────────────────────────────────────────────

  /// List all projects.
  Future<Map<String, dynamic>> listProjects() async {
    return _get('/api/v1/projects');
  }

  /// Create a new project.
  Future<Map<String, dynamic>> createProject(String name) async {
    return _post('/api/v1/projects', {'name': name});
  }

  /// Get project by ID.
  Future<Map<String, dynamic>> getProjectById(String projectId) async {
    return _get('/api/v1/projects/$projectId');
  }

  /// Update a project by ID.
  Future<Map<String, dynamic>> updateProjectById(String projectId, Map<String, dynamic> data) async {
    return _patch('/api/v1/projects/$projectId', data);
  }

  /// Delete a project.
  Future<void> deleteProject(String projectId) async {
    await _delete('/api/v1/projects/$projectId');
  }

  /// Set a project as the default.
  Future<Map<String, dynamic>> setDefaultProject(String projectId) async {
    return _patch('/api/v1/projects/$projectId/default', {});
  }

  // ── Teams ─────────────────────────────────────────────────────────────

  /// List members of a project.
  Future<Map<String, dynamic>> listMembers(String projectId) async {
    return _get('/api/v1/projects/$projectId/members');
  }

  /// Add a member to a project.
  Future<Map<String, dynamic>> addMember(String projectId, String email, {String role = 'member'}) async {
    return _post('/api/v1/projects/$projectId/members', {'email': email, 'role': role});
  }

  /// Update a member's role.
  Future<Map<String, dynamic>> updateMember(String projectId, String memberId, String role) async {
    return _patch('/api/v1/projects/$projectId/members/$memberId', {'role': role});
  }

  /// Remove a member from a project.
  Future<void> removeMember(String projectId, String memberId) async {
    await _delete('/api/v1/projects/$projectId/members/$memberId');
  }

  // ── Invitations ───────────────────────────────────────────────────────

  /// List pending invitations for the current user.
  Future<Map<String, dynamic>> listPendingInvitations() async {
    return _get('/api/v1/invitations/pending');
  }

  /// Accept an invitation.
  Future<Map<String, dynamic>> acceptInvitation(String invitationId) async {
    return _post('/api/v1/invitations/$invitationId/accept', {});
  }

  /// Reject an invitation.
  Future<Map<String, dynamic>> rejectInvitation(String invitationId) async {
    return _post('/api/v1/invitations/$invitationId/reject', {});
  }

  // ── Audit ─────────────────────────────────────────────────────────────

  /// List audit log entries.
  Future<Map<String, dynamic>> listAuditLogs({int limit = 50, String? cursor}) async {
    return _get('/api/v1/audit-log', params: {'limit': '$limit', if (cursor != null) 'cursor': cursor});
  }

  // ── Embed Tokens ────────────────────────────────────────────────────

  /// List embed tokens.
  Future<Map<String, dynamic>> listEmbedTokens() async {
    return _get('/api/v1/embed/tokens');
  }

  /// Create an embed token.
  Future<Map<String, dynamic>> createEmbedToken(Map<String, dynamic> config) async {
    return _post('/api/v1/embed/tokens', config);
  }

  /// Revoke an embed token.
  Future<void> revokeEmbedToken(String id) async {
    await _delete('/api/v1/embed/tokens/$id');
  }

  // ── Notification Channels ────────────────────────────────────────────

  /// Get the notification channel configuration.
  Future<Map<String, dynamic>> getNotificationChannel() async {
    return _get('/api/v1/notification-channels');
  }

  /// Create or update notification channel configuration.
  Future<Map<String, dynamic>> upsertNotificationChannel(Map<String, dynamic> config) async {
    return _put('/api/v1/notification-channels', config);
  }

  /// Delete the notification channel configuration.
  Future<void> deleteNotificationChannel() async {
    await _delete('/api/v1/notification-channels');
  }

  /// Test the notification channel configuration.
  Future<Map<String, dynamic>> testNotificationChannel() async {
    return _post('/api/v1/notification-channels/test', {});
  }

  // ── Export ─────────────────────────────────────────────────────────────

  /// Export events as CSV or JSON. Returns raw string.
  Future<String> exportEvents({String format = 'csv'}) async {
    return _getRaw('/api/v1/export/events', params: {'format': format});
  }

  /// Export deliveries as CSV or JSON. Returns raw string.
  Future<String> exportDeliveries({String format = 'csv'}) async {
    return _getRaw('/api/v1/export/deliveries', params: {'format': format});
  }

  /// Export jobs as CSV or JSON. Returns raw string.
  Future<String> exportJobs({String format = 'csv'}) async {
    return _getRaw('/api/v1/export/jobs', params: {'format': format});
  }

  /// Export audit log as CSV or JSON. Returns raw string.
  Future<String> exportAuditLog({String format = 'csv'}) async {
    return _getRaw('/api/v1/export/audit-log', params: {'format': format});
  }

  // ── GDPR ──────────────────────────────────────────────────────────────

  /// Get current user consent status.
  Future<Map<String, dynamic>> getConsents() async {
    return _get('/api/v1/me/consents');
  }

  /// Accept consent for a specific purpose.
  Future<Map<String, dynamic>> acceptConsent(String purpose) async {
    return _post('/api/v1/me/consents/$purpose/accept', {});
  }

  /// Export all personal data (GDPR data portability).
  Future<Map<String, dynamic>> exportMyData() async {
    return _get('/api/v1/me/data');
  }

  /// Request restriction of data processing.
  Future<Map<String, dynamic>> restrictProcessing() async {
    return _post('/api/v1/me/restrict', {});
  }

  /// Lift restriction on data processing.
  Future<void> liftRestriction() async {
    await _delete('/api/v1/me/restrict');
  }

  /// Object to data processing.
  Future<Map<String, dynamic>> objectToProcessing() async {
    return _post('/api/v1/me/object', {});
  }

  /// Withdraw objection to data processing.
  Future<void> restoreConsent() async {
    await _delete('/api/v1/me/object');
  }

  // ── Health ─────────────────────────────────────────────────────────────

  /// Check API health.
  Future<Map<String, dynamic>> health() async {
    return _get('/health');
  }

  /// Get platform status.
  Future<Map<String, dynamic>> status() async {
    return _get('/status');
  }

  // ── Private HTTP helpers ──────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? params}) async {
    return _request('GET', path, params: params);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    return _request('POST', path, body: body);
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    return _request('PUT', path, body: body);
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    return _request('PATCH', path, body: body);
  }

  Future<void> _delete(String path) async {
    await _request('DELETE', path);
  }

  Future<String> _getRaw(String path, {Map<String, String>? params}) async {
    final uri = _buildUri(path, params);
    final headers = <String, String>{
      'X-Api-Key': _apiKey,
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };

    final response = await _httpClient.get(uri, headers: headers);

    if (response.statusCode >= 400) {
      throw JobcelisException(response.statusCode, response.body);
    }

    return response.body;
  }

  Future<Map<String, dynamic>> _publicPost(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseURL$path');
    final response = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _request(String method, String path, {Map<String, String>? params, Map<String, dynamic>? body}) async {
    final uri = _buildUri(path, params);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Api-Key': _apiKey,
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };

    http.Response response;
    final encodedBody = body != null ? jsonEncode(body) : null;

    switch (method) {
      case 'GET':
        response = await _httpClient.get(uri, headers: headers);
        break;
      case 'POST':
        response = await _httpClient.post(uri, headers: headers, body: encodedBody);
        break;
      case 'PUT':
        response = await _httpClient.put(uri, headers: headers, body: encodedBody);
        break;
      case 'PATCH':
        response = await _httpClient.patch(uri, headers: headers, body: encodedBody);
        break;
      case 'DELETE':
        response = await _httpClient.delete(uri, headers: headers);
        break;
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 204) return {};

    if (response.statusCode >= 400) {
      throw JobcelisException(response.statusCode, response.body);
    }

    if (response.body.isEmpty) return {};

    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Uri _buildUri(String path, Map<String, String>? params) {
    final base = Uri.parse('$_baseURL$path');
    if (params == null || params.isEmpty) return base;
    return base.replace(queryParameters: params);
  }
}
