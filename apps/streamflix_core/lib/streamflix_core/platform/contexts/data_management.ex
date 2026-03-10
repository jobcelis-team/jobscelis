defmodule StreamflixCore.Platform.DataManagement do
  @moduledoc """
  Functions for manual data purge and retention management.
  """
  import Ecto.Query
  require Logger

  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{AuditLog, Delivery, WebhookEvent, DeadLetter, Project}

  @valid_types ~w(events deliveries audit_logs dead_letters)
  @valid_retention_values [30, 90, 180, 365, 0]

  @doc """
  Updates retention policy for a project.
  Policy is a map like: %{"events_days" => 90, "deliveries_days" => 30, "audit_logs_days" => 365}
  Value of 0 means unlimited (no auto-purge).
  """
  def update_retention_policy(project, policy) do
    case validate_policy(policy) do
      {:ok, clean_policy} ->
        project
        |> Project.changeset(%{retention_policy: clean_policy})
        |> Repo.update()

      {:error, _} = err ->
        err
    end
  end

  defp validate_policy(policy) when is_map(policy) do
    valid_keys = ["events_days", "deliveries_days", "audit_logs_days"]

    clean =
      Enum.reduce(valid_keys, %{}, fn key, acc ->
        case Map.get(policy, key) do
          nil -> acc
          val when is_integer(val) and val in @valid_retention_values -> Map.put(acc, key, val)
          val when is_integer(val) and val >= 1 -> Map.put(acc, key, val)
          _ -> acc
        end
      end)

    {:ok, clean}
  end

  defp validate_policy(_), do: {:error, :invalid_policy}

  @doc """
  Manual purge: delete data for a project matching criteria.

  Options:
  - type: "events" | "deliveries" | "audit_logs" | "dead_letters"
  - older_than: Date string "YYYY-MM-DD" (required)
  - topic: optional topic filter (for events/deliveries)
  - status: optional status filter (for deliveries: "success", "failed")

  Returns {:ok, %{type: type, deleted_count: count}} or {:error, reason}
  """
  def manual_purge(project_id, params) do
    type = Map.get(params, "type", "")
    older_than_str = Map.get(params, "older_than", "")
    topic = Map.get(params, "topic")
    status = Map.get(params, "status")

    with true <- type in @valid_types,
         {:ok, older_than} <- parse_date(older_than_str) do
      cutoff = DateTime.new!(older_than, ~T[00:00:00], "Etc/UTC")

      count =
        case type do
          "events" -> purge_events(project_id, cutoff, topic)
          "deliveries" -> purge_deliveries(project_id, cutoff, topic, status)
          "audit_logs" -> purge_audit_logs(project_id, cutoff)
          "dead_letters" -> purge_dead_letters(project_id, cutoff)
        end

      Logger.info("Manual purge completed",
        worker: "DataManagement",
        project_id: project_id,
        type: type,
        older_than: older_than_str,
        deleted_count: count
      )

      {:ok, %{type: type, deleted_count: count, older_than: older_than_str}}
    else
      false -> {:error, :invalid_type}
      {:error, _} -> {:error, :invalid_date}
    end
  end

  @doc """
  Preview: count how many records would be deleted without actually deleting.
  Same params as manual_purge.
  """
  def preview_purge(project_id, params) do
    type = Map.get(params, "type", "")
    older_than_str = Map.get(params, "older_than", "")
    topic = Map.get(params, "topic")
    status = Map.get(params, "status")

    with true <- type in @valid_types,
         {:ok, older_than} <- parse_date(older_than_str) do
      cutoff = DateTime.new!(older_than, ~T[00:00:00], "Etc/UTC")

      count =
        case type do
          "events" -> count_events(project_id, cutoff, topic)
          "deliveries" -> count_deliveries(project_id, cutoff, topic, status)
          "audit_logs" -> count_audit_logs(project_id, cutoff)
          "dead_letters" -> count_dead_letters(project_id, cutoff)
        end

      {:ok, %{type: type, count: count, older_than: older_than_str}}
    else
      false -> {:error, :invalid_type}
      {:error, _} -> {:error, :invalid_date}
    end
  end

  # Private purge functions
  defp purge_events(project_id, cutoff, topic) do
    query =
      from(e in WebhookEvent,
        where: e.project_id == ^project_id and e.inserted_at < ^cutoff
      )

    query = if topic, do: where(query, [e], like(e.topic, ^topic_pattern(topic))), else: query
    {count, _} = Repo.delete_all(query)
    count
  end

  defp purge_deliveries(project_id, cutoff, topic, status) do
    query =
      from(d in Delivery,
        join: e in WebhookEvent,
        on: d.event_id == e.id,
        where: e.project_id == ^project_id and d.inserted_at < ^cutoff
      )

    query = if topic, do: where(query, [d, e], like(e.topic, ^topic_pattern(topic))), else: query
    query = if status, do: where(query, [d], d.status == ^status), else: query
    {count, _} = Repo.delete_all(query)
    count
  end

  defp purge_audit_logs(project_id, cutoff) do
    {count, _} =
      from(a in AuditLog,
        where: a.project_id == ^project_id and a.inserted_at < ^cutoff
      )
      |> Repo.delete_all()

    count
  end

  defp purge_dead_letters(project_id, cutoff) do
    {count, _} =
      from(dl in DeadLetter,
        where: dl.project_id == ^project_id and dl.inserted_at < ^cutoff
      )
      |> Repo.delete_all()

    count
  end

  # Count functions (same queries but with count)
  defp count_events(project_id, cutoff, topic) do
    query =
      from(e in WebhookEvent,
        where: e.project_id == ^project_id and e.inserted_at < ^cutoff,
        select: count()
      )

    query = if topic, do: where(query, [e], like(e.topic, ^topic_pattern(topic))), else: query
    Repo.one(query)
  end

  defp count_deliveries(project_id, cutoff, topic, status) do
    query =
      from(d in Delivery,
        join: e in WebhookEvent,
        on: d.event_id == e.id,
        where: e.project_id == ^project_id and d.inserted_at < ^cutoff,
        select: count()
      )

    query = if topic, do: where(query, [d, e], like(e.topic, ^topic_pattern(topic))), else: query
    query = if status, do: where(query, [d], d.status == ^status), else: query
    Repo.one(query)
  end

  defp count_audit_logs(project_id, cutoff) do
    from(a in AuditLog,
      where: a.project_id == ^project_id and a.inserted_at < ^cutoff,
      select: count()
    )
    |> Repo.one()
  end

  defp count_dead_letters(project_id, cutoff) do
    from(dl in DeadLetter,
      where: dl.project_id == ^project_id and dl.inserted_at < ^cutoff,
      select: count()
    )
    |> Repo.one()
  end

  defp parse_date(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, :invalid_date}
    end
  end

  defp parse_date(_), do: {:error, :invalid_date}

  defp topic_pattern(topic) do
    topic
    |> String.replace("*", "%")
    |> String.replace("?", "_")
  end
end
