defmodule StreamflixCore.Platform.DataManagementTest do
  use StreamflixCore.DataCase, async: true

  alias StreamflixCore.Platform

  defp event_at(project, iso) do
    {:ok, dt, _} = DateTime.from_iso8601(iso)
    insert(:webhook_event, project_id: project.id, inserted_at: dt, occurred_at: dt)
  end

  describe "purge cutoff" do
    setup do
      project = insert(:project)
      # 03:00 UTC on the 17th is still the 16th in Ecuador (UTC-5)
      event_at(project, "2026-10-17T03:00:00Z")
      event_at(project, "2026-10-17T06:00:00Z")
      %{project: project}
    end

    test "a plain date is midnight UTC", %{project: project} do
      assert {:ok, %{count: 0}} =
               Platform.preview_purge(project.id, %{
                 "type" => "events",
                 "older_than" => "2026-10-17"
               })
    end

    test "an ISO datetime with offset is used as the exact cutoff", %{project: project} do
      # Local midnight of the 17th in UTC-5 = 05:00 UTC
      params = %{"type" => "events", "older_than" => "2026-10-17T05:00:00.000Z"}
      assert {:ok, %{count: 1}} = Platform.preview_purge(project.id, params)

      params = %{"type" => "events", "older_than" => "2026-10-17T00:00:00-05:00"}
      assert {:ok, %{count: 1}} = Platform.preview_purge(project.id, params)
    end

    test "invalid values are rejected", %{project: project} do
      assert {:error, :invalid_date} =
               Platform.preview_purge(project.id, %{
                 "type" => "events",
                 "older_than" => "17/10/2026"
               })
    end
  end
end
