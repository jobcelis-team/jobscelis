defmodule StreamflixCore.Platform.ObanScheduledJobWorkerTest do
  @moduledoc """
  Tests for the ObanScheduledJobWorker and ScheduledJobRunner.
  """
  use StreamflixCore.DataCase, async: false

  alias StreamflixCore.Platform.ObanScheduledJobWorker
  alias StreamflixCore.Schemas.JobRun

  setup do
    user = create_test_user()
    project = insert(:project, user_id: user.id)
    %{project: project, user: user}
  end

  describe "perform/1 — emit_event action" do
    test "creates event and records successful job run", %{project: project} do
      job =
        insert(:job,
          project_id: project.id,
          action_type: "emit_event",
          action_config: %{"topic" => "scheduled.test", "payload" => %{"source" => "cron"}},
          status: "active"
        )

      oban_job = %Oban.Job{args: %{"job_id" => job.id}}
      assert :ok = ObanScheduledJobWorker.perform(oban_job)

      runs = JobRun |> Ecto.Query.where([r], r.job_id == ^job.id) |> Repo.all()
      assert length(runs) == 1
      assert hd(runs).status == "success"
    end
  end

  describe "perform/1 — inactive job" do
    test "returns :ok for inactive job", %{project: project} do
      job =
        insert(:job,
          project_id: project.id,
          action_type: "emit_event",
          action_config: %{"topic" => "test"},
          status: "inactive"
        )

      oban_job = %Oban.Job{args: %{"job_id" => job.id}}
      assert :ok = ObanScheduledJobWorker.perform(oban_job)

      runs = JobRun |> Ecto.Query.where([r], r.job_id == ^job.id) |> Repo.all()
      assert runs == []
    end
  end

  describe "perform/1 — non-existent job" do
    test "returns :ok for missing job_id" do
      oban_job = %Oban.Job{args: %{"job_id" => Ecto.UUID.generate()}}
      assert :ok = ObanScheduledJobWorker.perform(oban_job)
    end
  end

  describe "perform/1 — post_url action (no HTTP)" do
    test "records failure for missing url", %{project: project} do
      job =
        insert(:job,
          project_id: project.id,
          action_type: "post_url",
          action_config: %{"payload" => %{}},
          status: "active"
        )

      oban_job = %Oban.Job{args: %{"job_id" => job.id}}
      assert :ok = ObanScheduledJobWorker.perform(oban_job)

      runs = JobRun |> Ecto.Query.where([r], r.job_id == ^job.id) |> Repo.all()
      assert length(runs) == 1
      assert hd(runs).status == "failed"
    end
  end
end
