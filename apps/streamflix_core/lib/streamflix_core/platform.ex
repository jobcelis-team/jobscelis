defmodule StreamflixCore.Platform do
  @moduledoc """
  Facade for the Webhooks + Events platform.
  Delegates to specialized sub-modules for maintainability.
  All "delete" operations set status to inactive (soft delete).
  """

  # ---------- Projects ----------
  defdelegate create_project(attrs), to: StreamflixCore.Platform.Projects
  defdelegate get_project(id), to: StreamflixCore.Platform.Projects
  defdelegate get_project!(id), to: StreamflixCore.Platform.Projects
  defdelegate get_default_project_for_user(user_id), to: StreamflixCore.Platform.Projects
  defdelegate set_default_project(user_id, project_id), to: StreamflixCore.Platform.Projects
  defdelegate delete_project(project), to: StreamflixCore.Platform.Projects
  defdelegate list_projects(), to: StreamflixCore.Platform.Projects
  defdelegate list_projects(opts), to: StreamflixCore.Platform.Projects
  defdelegate list_projects_for_user(user_id), to: StreamflixCore.Platform.Projects
  defdelegate list_projects_for_user(user_id, opts), to: StreamflixCore.Platform.Projects
  defdelegate update_project(project, attrs), to: StreamflixCore.Platform.Projects
  defdelegate set_project_inactive(project), to: StreamflixCore.Platform.Projects

  # ---------- API Keys ----------
  defdelegate create_api_key(project_id), to: StreamflixCore.Platform.ApiKeys
  defdelegate create_api_key(project_id, attrs), to: StreamflixCore.Platform.ApiKeys
  defdelegate verify_api_key(prefix, raw_key), to: StreamflixCore.Platform.ApiKeys
  defdelegate get_api_key_for_project(project_id), to: StreamflixCore.Platform.ApiKeys
  defdelegate regenerate_api_key(project_id), to: StreamflixCore.Platform.ApiKeys

  # ---------- Webhooks ----------
  defdelegate create_webhook(project_id, attrs), to: StreamflixCore.Platform.Webhooks
  defdelegate list_webhooks(project_id), to: StreamflixCore.Platform.Webhooks
  defdelegate list_webhooks(project_id, opts), to: StreamflixCore.Platform.Webhooks
  defdelegate get_webhook(id), to: StreamflixCore.Platform.Webhooks
  defdelegate get_webhook!(id), to: StreamflixCore.Platform.Webhooks
  defdelegate update_webhook(webhook, attrs), to: StreamflixCore.Platform.Webhooks
  defdelegate set_webhook_inactive(webhook), to: StreamflixCore.Platform.Webhooks

  defdelegate list_active_webhooks_for_project(project_id),
    to: StreamflixCore.Platform.Webhooks

  defdelegate webhook_matches_event?(webhook, event), to: StreamflixCore.Platform.Webhooks
  defdelegate webhook_templates(), to: StreamflixCore.Platform.Webhooks
  defdelegate webhook_health(webhook_id), to: StreamflixCore.Platform.Webhooks
  defdelegate webhooks_health(project_id), to: StreamflixCore.Platform.Webhooks

  defdelegate invalidate_webhook_health_cache(project_id),
    to: StreamflixCore.Platform.Webhooks

  defdelegate simulate_event(project_id, body), to: StreamflixCore.Platform.Webhooks
  defdelegate test_webhook(webhook_id), to: StreamflixCore.Platform.Webhooks

  # ---------- Events ----------
  defdelegate create_event(project_id, body), to: StreamflixCore.Platform.Events
  defdelegate create_events_batch(project_id, events), to: StreamflixCore.Platform.Events
  defdelegate list_events(project_id), to: StreamflixCore.Platform.Events
  defdelegate list_events(project_id, opts), to: StreamflixCore.Platform.Events
  defdelegate get_event(id), to: StreamflixCore.Platform.Events
  defdelegate get_event!(id), to: StreamflixCore.Platform.Events
  defdelegate list_topics_used(project_id), to: StreamflixCore.Platform.Events
  defdelegate set_event_inactive(event), to: StreamflixCore.Platform.Events
  defdelegate search_events(project_id, query_params), to: StreamflixCore.Platform.Events
  defdelegate search_events(project_id, query_params, opts), to: StreamflixCore.Platform.Events
  defdelegate process_delayed_events(), to: StreamflixCore.Platform.Events
  defdelegate user_processing_allowed?(user_id), to: StreamflixCore.Platform.Events

  # ---------- Deliveries ----------
  defdelegate list_deliveries(), to: StreamflixCore.Platform.Deliveries
  defdelegate list_deliveries(opts), to: StreamflixCore.Platform.Deliveries
  defdelegate get_delivery(id), to: StreamflixCore.Platform.Deliveries
  defdelegate get_delivery!(id), to: StreamflixCore.Platform.Deliveries
  defdelegate update_delivery_to_pending(delivery), to: StreamflixCore.Platform.Deliveries
  defdelegate retry_delivery(project_id, delivery_id), to: StreamflixCore.Platform.Deliveries
  defdelegate build_webhook_body(webhook, event), to: StreamflixCore.Platform.Deliveries

  # ---------- Jobs ----------
  defdelegate create_job(project_id, attrs), to: StreamflixCore.Platform.Jobs
  defdelegate list_jobs(project_id), to: StreamflixCore.Platform.Jobs
  defdelegate list_jobs(project_id, opts), to: StreamflixCore.Platform.Jobs
  defdelegate get_job(id), to: StreamflixCore.Platform.Jobs
  defdelegate get_job!(id), to: StreamflixCore.Platform.Jobs
  defdelegate update_job(job, attrs), to: StreamflixCore.Platform.Jobs
  defdelegate set_job_inactive(job), to: StreamflixCore.Platform.Jobs
  defdelegate list_jobs_to_run_now(), to: StreamflixCore.Platform.Jobs
  defdelegate next_cron_executions(cron_expr), to: StreamflixCore.Platform.Jobs
  defdelegate next_cron_executions(cron_expr, count), to: StreamflixCore.Platform.Jobs
  defdelegate list_job_runs(job_id), to: StreamflixCore.Platform.Jobs
  defdelegate list_job_runs(job_id, opts), to: StreamflixCore.Platform.Jobs

  # ---------- Dead Letters ----------
  defdelegate create_dead_letter(attrs), to: StreamflixCore.Platform.DeadLetters
  defdelegate list_dead_letters(project_id), to: StreamflixCore.Platform.DeadLetters
  defdelegate list_dead_letters(project_id, opts), to: StreamflixCore.Platform.DeadLetters
  defdelegate get_dead_letter(id), to: StreamflixCore.Platform.DeadLetters
  defdelegate resolve_dead_letter(id), to: StreamflixCore.Platform.DeadLetters
  defdelegate retry_dead_letter(id), to: StreamflixCore.Platform.DeadLetters
  defdelegate retry_dead_letter(id, modified_payload), to: StreamflixCore.Platform.DeadLetters

  # ---------- Replays ----------
  defdelegate create_replay(project_id, user_id, filters), to: StreamflixCore.Platform.Replays
  defdelegate list_replays(project_id), to: StreamflixCore.Platform.Replays
  defdelegate list_replays(project_id, opts), to: StreamflixCore.Platform.Replays
  defdelegate get_replay(id), to: StreamflixCore.Platform.Replays
  defdelegate cancel_replay(id), to: StreamflixCore.Platform.Replays

  # ---------- Sandbox ----------
  defdelegate create_sandbox_endpoint(project_id), to: StreamflixCore.Platform.Sandbox
  defdelegate create_sandbox_endpoint(project_id, name), to: StreamflixCore.Platform.Sandbox
  defdelegate list_sandbox_endpoints(project_id), to: StreamflixCore.Platform.Sandbox
  defdelegate get_sandbox_by_slug(slug), to: StreamflixCore.Platform.Sandbox
  defdelegate get_sandbox_endpoint(id), to: StreamflixCore.Platform.Sandbox
  defdelegate delete_sandbox_endpoint(id), to: StreamflixCore.Platform.Sandbox

  defdelegate record_sandbox_request(endpoint_id, attrs),
    to: StreamflixCore.Platform.Sandbox

  defdelegate list_sandbox_requests(endpoint_id), to: StreamflixCore.Platform.Sandbox
  defdelegate list_sandbox_requests(endpoint_id, opts), to: StreamflixCore.Platform.Sandbox

  # ---------- Analytics ----------
  defdelegate events_per_day(project_id), to: StreamflixCore.Platform.Analytics
  defdelegate events_per_day(project_id, days), to: StreamflixCore.Platform.Analytics
  defdelegate deliveries_per_day(project_id), to: StreamflixCore.Platform.Analytics
  defdelegate deliveries_per_day(project_id, days), to: StreamflixCore.Platform.Analytics
  defdelegate top_topics(project_id), to: StreamflixCore.Platform.Analytics
  defdelegate top_topics(project_id, limit_count), to: StreamflixCore.Platform.Analytics
  defdelegate delivery_stats_by_webhook(project_id), to: StreamflixCore.Platform.Analytics

  # ---------- Event Schemas ----------
  defdelegate create_event_schema(project_id, attrs), to: StreamflixCore.Platform.EventSchemas
  defdelegate list_event_schemas(project_id), to: StreamflixCore.Platform.EventSchemas
  defdelegate list_event_schemas(project_id, opts), to: StreamflixCore.Platform.EventSchemas
  defdelegate get_event_schema(id), to: StreamflixCore.Platform.EventSchemas
  defdelegate update_event_schema(schema, attrs), to: StreamflixCore.Platform.EventSchemas
  defdelegate delete_event_schema(schema), to: StreamflixCore.Platform.EventSchemas

  defdelegate validate_event_payload(project_id, topic, payload),
    to: StreamflixCore.Platform.EventSchemas

  defdelegate dry_validate_event_payload(project_id, topic, payload),
    to: StreamflixCore.Platform.EventSchemas

  # ---------- Pipelines ----------
  defdelegate create_pipeline(project_id, attrs), to: StreamflixCore.Platform.Pipelines
  defdelegate list_pipelines(project_id), to: StreamflixCore.Platform.Pipelines
  defdelegate list_pipelines(project_id, opts), to: StreamflixCore.Platform.Pipelines
  defdelegate get_pipeline(id), to: StreamflixCore.Platform.Pipelines
  defdelegate update_pipeline(pipeline, attrs), to: StreamflixCore.Platform.Pipelines
  defdelegate set_pipeline_inactive(pipeline), to: StreamflixCore.Platform.Pipelines
  defdelegate matching_pipelines(project_id, topic), to: StreamflixCore.Platform.Pipelines

  defdelegate execute_pipeline_steps(steps, payload),
    to: StreamflixCore.Platform.Pipelines,
    as: :execute_steps

  # ---------- Oban Monitor ----------
  defdelegate oban_queue_stats(), to: StreamflixCore.Platform.ObanMonitor, as: :queue_stats
  defdelegate oban_state_counts(), to: StreamflixCore.Platform.ObanMonitor, as: :state_counts
  defdelegate oban_list_jobs(), to: StreamflixCore.Platform.ObanMonitor, as: :list_jobs
  defdelegate oban_list_jobs(opts), to: StreamflixCore.Platform.ObanMonitor, as: :list_jobs
  defdelegate oban_cancel_job(job_id), to: StreamflixCore.Platform.ObanMonitor, as: :cancel_job
  defdelegate oban_retry_job(job_id), to: StreamflixCore.Platform.ObanMonitor, as: :retry_job
  defdelegate oban_purge_jobs(), to: StreamflixCore.Platform.ObanMonitor, as: :purge_jobs
  defdelegate oban_purge_jobs(days), to: StreamflixCore.Platform.ObanMonitor, as: :purge_jobs
  defdelegate oban_queues(), to: StreamflixCore.Platform.ObanMonitor, as: :queues

  # ---------- Pagination ----------
  defdelegate paginate_events(project_id), to: StreamflixCore.Platform.Pagination
  defdelegate paginate_events(project_id, opts), to: StreamflixCore.Platform.Pagination
  defdelegate paginate_deliveries(), to: StreamflixCore.Platform.Pagination
  defdelegate paginate_deliveries(opts), to: StreamflixCore.Platform.Pagination

  # ---------- PubSub ----------

  @pubsub StreamflixCore.PubSub

  @doc "Subscribe to real-time updates for a project"
  def subscribe(project_id) do
    Phoenix.PubSub.subscribe(@pubsub, "project:#{project_id}")
  end
end
