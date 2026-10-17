defmodule StreamflixCore.CircuitBreakerTest do
  use StreamflixCore.DataCase, async: false

  alias StreamflixCore.CircuitBreaker
  alias StreamflixCore.Schemas.{Notification, Webhook}

  defp types(user_id) do
    Repo.all(from(n in Notification, where: n.user_id == ^user_id, select: n.type))
  end

  test "warns once at 3 failures, opens once at 5, even with a stale struct" do
    project = insert(:project, user_id: create_test_user().id)
    stale = insert(:webhook, project_id: project.id)

    # Every call passes the same stale struct (consecutive_failures: 0)
    for _ <- 1..7, do: CircuitBreaker.record_failure(stale)

    webhook = Repo.get(Webhook, stale.id)
    assert webhook.consecutive_failures == 7
    assert webhook.circuit_state == "open"

    assert Enum.frequencies(types(project.user_id)) == %{
             "webhook_failing" => 1,
             "circuit_open" => 1
           }
  end

  test "a failed half-open probe re-opens without a second alert" do
    project = insert(:project, user_id: create_test_user().id)

    webhook =
      insert(:webhook,
        project_id: project.id,
        circuit_state: "half_open",
        consecutive_failures: 5
      )

    CircuitBreaker.record_failure(webhook)

    assert Repo.get(Webhook, webhook.id).circuit_state == "open"
    assert types(project.user_id) == []
  end
end
