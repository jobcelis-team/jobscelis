defmodule StreamflixCore.Platform.ScheduledJobRunner do
  @moduledoc """
  Runs one platform scheduled job: emit_event or post_url.
  """
  import Ecto.Query
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
      {:error, reason} -> record_run(job, "failed", %{error: format_error(reason)})
    end
  end

  @http_methods %{
    "GET" => :get,
    "POST" => :post,
    "PUT" => :put,
    "PATCH" => :patch,
    "DELETE" => :delete
  }

  defp run_post_url(job) do
    cfg = job.action_config || %{}
    url = cfg["url"]
    payload = maybe_substitute_date(cfg["payload"] || %{})
    method = Map.get(@http_methods, String.upcase(to_string(cfg["method"] || "POST")), :post)

    with true <- is_binary(url) and url != "",
         :ok <- StreamflixCore.Platform.UrlGuard.check(url) do
      request(job, method, url, payload)
    else
      false ->
        record_run(job, "failed", %{error: "missing url"})

      {:error, reason} ->
        record_run(job, "failed", %{
          error: "url " <> StreamflixCore.Platform.UrlGuard.message(reason)
        })
    end
  end

  defp request(job, method, url, payload) do
    opts =
      [
        method: method,
        url: url,
        receive_timeout: 15_000,
        finch: StreamflixCore.Finch,
        redirect: false,
        retry: false
      ] ++ if(method in [:get, :delete], do: [], else: [json: payload])

    case Req.request(opts) do
      {:ok, %{status: status}} when status in 200..299 ->
        record_run(job, "success", %{response_status: status})

      {:ok, %{status: status}} ->
        record_run(job, "failed", %{response_status: status, error: "HTTP #{status}"})

      {:error, reason} ->
        record_run(job, "failed", %{error: Exception.message(reason)})
    end
  rescue
    # e.g. malformed URL: record the failure instead of crashing the worker
    e -> record_run(job, "failed", %{error: Exception.message(e)})
  end

  defp format_error(%Ecto.Changeset{} = cs),
    do: inspect(Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end))

  defp format_error(reason), do: inspect(reason)

  defp maybe_substitute_date(payload) when is_map(payload) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    for {k, v} <- payload, into: %{} do
      v2 =
        cond do
          v == "{{date}}" or v == "{{ date }}" -> now
          is_map(v) -> maybe_substitute_date(v)
          true -> v
        end

      {k, v2}
    end
  end

  defp maybe_substitute_date(v), do: v

  defp last_run_status(job_id) do
    from(r in JobRun,
      where: r.job_id == ^job_id,
      order_by: [desc: r.executed_at],
      limit: 1,
      select: r.status
    )
    |> Repo.one()
  end

  defp record_run(job, status, result) do
    # Alert when a job starts failing, not on every failed run: a job running every
    # minute would otherwise send an alert per minute (same rule as failing webhooks).
    already_failing = status == "failed" and last_run_status(job.id) == "failed"

    run_result =
      JobRun.changeset(%JobRun{}, %{
        job_id: job.id,
        executed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
        status: status,
        result: result
      })
      |> Repo.insert()

    if status == "failed" and not already_failing and job.project do
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
