defmodule StreamflixCore.Repo.Migrations.DeduplicateConsents do
  use Ecto.Migration

  def up do
    # Delete duplicate active consents, keeping only the oldest per (user_id, purpose).
    # A consent is "active" when revoked_at IS NULL.
    execute("""
    DELETE FROM consents
    WHERE id IN (
      SELECT c.id
      FROM consents c
      INNER JOIN (
        SELECT user_id, purpose, MIN(granted_at) AS first_granted
        FROM consents
        WHERE revoked_at IS NULL
        GROUP BY user_id, purpose
        HAVING COUNT(*) > 1
      ) dups ON c.user_id = dups.user_id
            AND c.purpose = dups.purpose
            AND c.revoked_at IS NULL
            AND c.granted_at > dups.first_granted
    )
    """)

    # Add unique partial index to prevent future duplicates
    create(
      unique_index(:consents, [:user_id, :purpose],
        where: "revoked_at IS NULL",
        name: :consents_user_purpose_active_idx
      )
    )
  end

  def down do
    drop_if_exists(index(:consents, [:user_id, :purpose], name: :consents_user_purpose_active_idx))
  end
end
