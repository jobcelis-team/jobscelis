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
      assert Enum.all?(executions, &(DateTime.compare(&1, DateTime.utc_now()) == :gt))
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
end
