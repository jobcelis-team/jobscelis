defmodule StreamflixCore.Platform.ScheduledJobRunner do
  @moduledoc """
  Runs one platform scheduled job: emit_event or post_url.
  """
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{Job, JobRun}
  alias StreamflixCore.Platform

  def run(job_id) do
    job = Repo.get(Job, job_id) |> Repo.preload(:project)
    if job && job.status == "active" do
      do_run(job)
    else
      {:error, :not_found_or_inactive}
    end
  end

  defp do_run(job) do
    case job.action_type do
      "emit_event" -> run_emit_event(job)
      "post_url" -> run_post_url(job)
      _ -> record_run(job, "failed", %{error: "unknown action_type"})
    end
  end

  defp run_emit_event(job) do
    cfg = job.action_config || %{}
    topic = cfg["topic"]
    payload = cfg["payload"] || %{}
    payload = maybe_substitute_date(payload)
    body = if topic, do: Map.put(payload, "topic", topic), else: payload
    case Platform.create_event(job.project_id, body) do
      {:ok, event} -> record_run(job, "success", %{event_id: event.id})
      {:error, _} -> record_run(job, "failed", %{})
    end
  end

  defp run_post_url(job) do
    cfg = job.action_config || %{}
    url = cfg["url"]
    payload = cfg["payload"] || %{}
    payload = maybe_substitute_date(payload)
    if is_binary(url) and url != "" do
      case Req.post(url, json: payload, receive_timeout: 15_000, finch: StreamflixCore.Finch) do
        {:ok, %{status: status}} -> record_run(job, "success", %{response_status: status})
        {:error, reason} -> record_run(job, "failed", %{error: inspect(reason)})
      end
    else
      record_run(job, "failed", %{error: "missing url"})
    end
  end

  defp maybe_substitute_date(payload) when is_map(payload) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    for {k, v} <- payload, into: %{} do
      v2 = cond do
        v == "{{date}}" or v == "{{ date }}" -> now
        is_map(v) -> maybe_substitute_date(v)
        true -> v
      end
      {k, v2}
    end
  end
  defp maybe_substitute_date(v), do: v

  defp record_run(job, status, result) do
    run_result =
      JobRun.changeset(%JobRun{}, %{
        job_id: job.id,
        executed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
        status: status,
        result: result
      }) |> Repo.insert()

    if status == "failed" and job.project do
      project = job.project

      if project.user_id do
        StreamflixCore.Notifications.notify_job_failed(
          project.user_id,
          project.id,
          job.name
        )
      end
    end

    run_result
  end
end
