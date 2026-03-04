defmodule StreamflixCore.Platform.ObanSessionCleanupWorker do
  @moduledoc """
  Purges expired and revoked user sessions older than 7 days.
  Runs daily at 4:00 AM UTC.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 3600]

  import Ecto.Query
  alias StreamflixCore.Repo

  @retention_days 7

  @impl Oban.Worker
  def perform(_job) do
    cutoff = DateTime.utc_now() |> DateTime.add(-@retention_days, :day)

    # Delete revoked sessions older than 7 days
    {revoked_count, _} =
      from(s in "user_sessions",
        where: not is_nil(s.revoked_at) and s.revoked_at < ^cutoff
      )
      |> Repo.delete_all()

    # Delete inactive sessions older than 7 days (no activity)
    {inactive_count, _} =
      from(s in "user_sessions",
        where: is_nil(s.revoked_at) and s.inserted_at < ^cutoff
      )
      |> Repo.delete_all()

    {:ok, %{revoked_purged: revoked_count, inactive_purged: inactive_count}}
  end
end
