defmodule StreamflixCore.Platform.JobsTest do
  use StreamflixCore.DataCase, async: true

  alias StreamflixCore.Platform

  describe "create_job/2" do
    test "creates a job with valid data" do
      project = insert(:project)

      attrs = %{
        "name" => "Daily Report",
        "schedule_type" => "daily",
        "schedule_config" => %{"hour" => 8, "minute" => 0},
        "action_type" => "emit_event",
        "action_config" => %{"topic" => "report.daily"}
      }

      assert {:ok, job} = Platform.create_job(project.id, attrs)
      assert job.name == "Daily Report"
      assert job.schedule_type == "daily"
      assert job.status == "active"
    end

    test "rejects job without required fields" do
      project = insert(:project)
      assert {:error, changeset} = Platform.create_job(project.id, %{})
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :name)
      assert Map.has_key?(errors, :schedule_type)
      assert Map.has_key?(errors, :action_type)
    end

    test "rejects invalid schedule_type" do
      project = insert(:project)

      attrs = %{
        "name" => "Bad Job",
        "schedule_type" => "hourly",
        "action_type" => "emit_event"
      }

      assert {:error, changeset} = Platform.create_job(project.id, attrs)
      assert %{schedule_type: _} = errors_on(changeset)
    end
  end

  describe "list_jobs/2" do
    test "lists active jobs for a project" do
      project = insert(:project)
      insert(:job, project_id: project.id, status: "active")
      insert(:job, project_id: project.id, status: "inactive")

      jobs = Platform.list_jobs(project.id)
      assert length(jobs) == 1
    end
  end

  describe "set_job_inactive/1" do
    test "soft deletes a job" do
      project = insert(:project)
      job = insert(:job, project_id: project.id, status: "active")

      assert {:ok, updated} = Platform.set_job_inactive(job)
      assert updated.status == "inactive"
    end
  end

  describe "list_job_runs/2" do
    test "lists runs for a job" do
      project = insert(:project)
      job = insert(:job, project_id: project.id)
      insert(:job_run, job_id: job.id, status: "success")
      insert(:job_run, job_id: job.id, status: "failed")

      runs = Platform.list_job_runs(job.id)
      assert length(runs) == 2
    end

    test "respects limit" do
      project = insert(:project)
      job = insert(:job, project_id: project.id)
      for _ <- 1..5, do: insert(:job_run, job_id: job.id)

      runs = Platform.list_job_runs(job.id, limit: 3)
      assert length(runs) == 3
    end
  end

  describe "cron matching" do
    test "next_cron_executions returns future times" do
      executions = Platform.next_cron_executions("* * * * *", 3)
      assert length(executions) == 3
      assert Enum.all?(executions, &(DateTime.compare(&1, DateTime.utc_now()) != :lt))
    end

    test "next_cron_executions for specific time" do
      executions = Platform.next_cron_executions("0 12 * * *", 2)
      assert length(executions) == 2
      assert Enum.all?(executions, &(&1.hour == 12 && &1.minute == 0))
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  describe "schedule matching" do
    alias StreamflixCore.Platform.Jobs
    alias StreamflixCore.Schemas.Job

    defp job(type, cfg), do: %Job{schedule_type: type, schedule_config: cfg}

    test "cron uses the real year (day-of-week) and does not crash on Feb 29" do
      # 2028-02-29 is a Tuesday
      at = ~U[2028-02-29 10:15:00Z]
      assert Jobs.job_due?(job("cron", %{"expr" => "15 10 * * 2"}), at)
      refute Jobs.job_due?(job("cron", %{"expr" => "15 10 * * 1"}), at)
    end

    test "monthly day 31 runs on the last day of shorter months" do
      cfg = %{"day_of_month" => 31, "hour" => 9, "minute" => 0}
      assert Jobs.job_due?(job("monthly", cfg), ~U[2026-02-28 09:00:30Z])
      assert Jobs.job_due?(job("monthly", cfg), ~U[2026-04-30 09:00:00Z])
      refute Jobs.job_due?(job("monthly", cfg), ~U[2026-03-30 09:00:00Z])
    end

    test "daily matches exactly one minute" do
      cfg = %{"hour" => 8, "minute" => 0}
      assert Jobs.job_due?(job("daily", cfg), ~U[2026-10-17 08:00:59Z])
      refute Jobs.job_due?(job("daily", cfg), ~U[2026-10-17 07:59:30Z])
      refute Jobs.job_due?(job("daily", cfg), ~U[2026-10-17 08:01:00Z])
    end

    test "weekly accepts 0 and 7 for Sunday" do
      sunday = ~U[2026-10-18 12:00:00Z]
      assert Jobs.job_due?(job("weekly", %{"day_of_week" => 0, "hour" => 12}), sunday)
      assert Jobs.job_due?(job("weekly", %{"day_of_week" => 7, "hour" => 12}), sunday)
    end

    test "invalid schedules are rejected at save time" do
      project = insert(:project)

      for {type, cfg} <- [
            {"cron", %{"expr" => "not a cron"}},
            {"daily", %{"hour" => 25}},
            {"monthly", %{"day_of_month" => 0}}
          ] do
        assert {:error, _} =
                 Platform.create_job(project.id, %{
                   "name" => "x",
                   "schedule_type" => type,
                   "schedule_config" => cfg,
                   "action_type" => "emit_event",
                   "action_config" => %{"topic" => "t"}
                 })
      end
    end
  end

  describe "scheduler catch-up" do
    alias StreamflixCore.Platform.Scheduler

    test "a skipped minute is still processed" do
      last = ~U[2026-10-17 10:00:00Z]

      assert Scheduler.slots_to_run(~U[2026-10-17 10:02:00Z], last) ==
               [~U[2026-10-17 10:01:00Z], ~U[2026-10-17 10:02:00Z]]

      assert Scheduler.slots_to_run(last, last) == []
    end
  end
end
