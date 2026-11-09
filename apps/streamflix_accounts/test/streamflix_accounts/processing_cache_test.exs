defmodule StreamflixAccounts.ProcessingCacheTest do
  @moduledoc """
  The GDPR processing permission is cached for event ingestion; restricting or
  lifting it must take effect on the very next event.
  """
  use StreamflixAccounts.DataCase, async: false

  alias StreamflixCore.Platform

  test "restriction and lifting apply to the next event despite the cache" do
    {:ok, user, _} =
      StreamflixAccounts.register_user(%{
        email: "cache#{System.unique_integer([:positive])}@example.com",
        password: "SecurePass123!",
        name: "Cache"
      })

    {:ok, project} = Platform.Projects.create_project(%{name: "P", user_id: user.id})

    # warm the cache with "allowed"
    assert {:ok, _} = Platform.create_event(project.id, %{"topic" => "t"})

    {:ok, user} = StreamflixCore.GDPR.restrict_processing(user, "test")
    assert {:error, :processing_restricted} = Platform.create_event(project.id, %{"topic" => "t"})

    assert {:error, :processing_restricted} =
             Platform.create_events_batch(project.id, [%{"topic" => "t"}])

    {:ok, _} = StreamflixCore.GDPR.lift_restriction(user)
    assert {:ok, _} = Platform.create_event(project.id, %{"topic" => "t"})
  end
end
