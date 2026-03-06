defmodule StreamflixCore.NotificationsTest do
  use StreamflixCore.DataCase

  alias StreamflixCore.Notifications

  setup do
    user = create_test_user()
    project = insert(:project, user_id: user.id)
    %{user: user, project: project}
  end

  describe "create/1" do
    test "creates a notification", %{user: user, project: project} do
      assert {:ok, notif} =
               Notifications.create(%{
                 user_id: user.id,
                 project_id: project.id,
                 type: "webhook_failing",
                 title: "Test alert",
                 message: "Something failed"
               })

      assert notif.read == false
      assert notif.type == "webhook_failing"
    end
  end

  describe "list_for_user/2" do
    test "returns notifications ordered by newest", %{user: user, project: project} do
      {:ok, _} =
        Notifications.create(%{
          user_id: user.id,
          project_id: project.id,
          type: "job_failed",
          title: "First"
        })

      {:ok, _} =
        Notifications.create(%{
          user_id: user.id,
          project_id: project.id,
          type: "dlq_entry",
          title: "Second"
        })

      notifs = Notifications.list_for_user(user.id)
      assert length(notifs) == 2
      assert hd(notifs).title == "Second"
    end

    test "filters unread only", %{user: user, project: project} do
      {:ok, n1} =
        Notifications.create(%{
          user_id: user.id,
          project_id: project.id,
          type: "job_failed",
          title: "Unread"
        })

      {:ok, _} = Notifications.mark_as_read(n1.id)

      {:ok, _} =
        Notifications.create(%{
          user_id: user.id,
          project_id: project.id,
          type: "dlq_entry",
          title: "Also unread"
        })

      unread = Notifications.list_for_user(user.id, unread_only: true)
      assert length(unread) == 1
    end
  end

  describe "unread_count/1" do
    test "counts unread notifications", %{user: user, project: project} do
      {:ok, _} =
        Notifications.create(%{
          user_id: user.id,
          project_id: project.id,
          type: "webhook_failing",
          title: "Alert 1"
        })

      {:ok, _} =
        Notifications.create(%{
          user_id: user.id,
          project_id: project.id,
          type: "job_failed",
          title: "Alert 2"
        })

      assert Notifications.unread_count(user.id) == 2
    end
  end

  describe "mark_as_read/1" do
    test "marks notification as read", %{user: user, project: project} do
      {:ok, notif} =
        Notifications.create(%{
          user_id: user.id,
          project_id: project.id,
          type: "dlq_entry",
          title: "Test"
        })

      assert {:ok, updated} = Notifications.mark_as_read(notif.id)
      assert updated.read == true
      assert updated.read_at != nil
    end

    test "returns error for not found" do
      assert {:error, :not_found} = Notifications.mark_as_read(Ecto.UUID.generate())
    end
  end

  describe "mark_all_read/1" do
    test "marks all user notifications as read", %{user: user, project: project} do
      {:ok, _} =
        Notifications.create(%{
          user_id: user.id,
          project_id: project.id,
          type: "webhook_failing",
          title: "A1"
        })

      {:ok, _} =
        Notifications.create(%{
          user_id: user.id,
          project_id: project.id,
          type: "job_failed",
          title: "A2"
        })

      assert {:ok, 2} = Notifications.mark_all_read(user.id)
      assert Notifications.unread_count(user.id) == 0
    end
  end

  describe "notification triggers" do
    test "notify_webhook_failing/3", %{user: user, project: project} do
      assert {:ok, n} =
               Notifications.notify_webhook_failing(user.id, project.id, "https://example.com")

      assert n.type == "webhook_failing"
    end

    test "notify_job_failed/3", %{user: user, project: project} do
      assert {:ok, n} = Notifications.notify_job_failed(user.id, project.id, "My Job")
      assert n.type == "job_failed"
    end

    test "notify_dlq_entry/3", %{user: user, project: project} do
      assert {:ok, n} =
               Notifications.notify_dlq_entry(user.id, project.id, "https://example.com")

      assert n.type == "dlq_entry"
    end

    test "notify_replay_completed/3", %{user: user, project: project} do
      assert {:ok, n} = Notifications.notify_replay_completed(user.id, project.id, 42)
      assert n.type == "replay_completed"
    end

    test "notify_team_invite/4", %{user: user, project: project} do
      member_id = Ecto.UUID.generate()

      assert {:ok, n} =
               Notifications.notify_team_invite(user.id, project.id, "editor", member_id)

      assert n.type == "team_invite"
      assert n.metadata["member_id"] == member_id
    end
  end
end
