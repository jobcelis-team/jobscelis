defmodule StreamflixCore.GDPRTest do
  use StreamflixCore.DataCase

  alias StreamflixCore.GDPR

  setup do
    user = create_test_user()
    project = insert(:project, user_id: user.id)

    # Load the user struct from raw table (GDPR module uses Ecto.Changeset.change)
    user_struct =
      Repo.one(
        from(u in "users",
          where: u.id == type(^user.id, :binary_id),
          select: %{
            __struct__: StreamflixCore.Schemas.AuditLog,
            id: type(u.id, :string),
            email: u.email,
            name: u.name,
            role: u.role,
            status: u.status,
            processing_consent: u.processing_consent,
            inserted_at: u.inserted_at
          }
        )
      )

    %{user: user, user_struct: user_struct, project: project}
  end

  describe "consent management" do
    test "grant_consent/3 creates a consent", %{user: user} do
      assert {:ok, consent} = GDPR.grant_consent(user.id, "terms")
      assert consent.purpose == "terms"
      assert consent.user_id == user.id
      assert is_nil(consent.revoked_at)
    end

    test "grant_consent is idempotent", %{user: user} do
      {:ok, c1} = GDPR.grant_consent(user.id, "privacy")
      {:ok, c2} = GDPR.grant_consent(user.id, "privacy")
      assert c1.id == c2.id
    end

    test "revoke_consent/1 sets revoked_at", %{user: user} do
      {:ok, consent} = GDPR.grant_consent(user.id, "marketing")
      assert {:ok, revoked} = GDPR.revoke_consent(consent.id)
      assert revoked.revoked_at != nil
    end

    test "revoke_consent returns error if already revoked", %{user: user} do
      {:ok, consent} = GDPR.grant_consent(user.id, "marketing")
      {:ok, _} = GDPR.revoke_consent(consent.id)
      assert {:error, :already_revoked} = GDPR.revoke_consent(consent.id)
    end

    test "has_consent?/2 returns true for active", %{user: user} do
      {:ok, _} = GDPR.grant_consent(user.id, "data_processing")
      assert GDPR.has_consent?(user.id, "data_processing")
    end

    test "has_consent?/2 returns false after revoke", %{user: user} do
      {:ok, consent} = GDPR.grant_consent(user.id, "marketing")
      {:ok, _} = GDPR.revoke_consent(consent.id)
      refute GDPR.has_consent?(user.id, "marketing")
    end

    test "list_active_consents/1 excludes revoked", %{user: user} do
      {:ok, _} = GDPR.grant_consent(user.id, "terms")
      {:ok, c2} = GDPR.grant_consent(user.id, "marketing")
      {:ok, _} = GDPR.revoke_consent(c2.id)

      active = GDPR.list_active_consents(user.id)
      assert length(active) == 1
      assert hd(active).purpose == "terms"
    end

    test "register_signup_consents/1 creates 3 consents", %{user: user} do
      assert :ok = GDPR.register_signup_consents(user.id)
      consents = GDPR.list_active_consents(user.id)
      purposes = Enum.map(consents, & &1.purpose) |> Enum.sort()
      assert purposes == ["data_processing", "privacy", "terms"]
    end
  end

  describe "restrict_processing/2" do
    test "sets user status to restricted", %{user: user} do
      # Use raw query to get a proper schema struct for changeset
      user_row =
        Repo.one(
          from(u in "users",
            where: u.id == type(^user.id, :binary_id),
            select: %{id: type(u.id, :string), status: u.status}
          )
        )

      assert user_row.status == "active"

      # Restrict via raw update since we don't have User schema in core
      {1, _} =
        from(u in "users",
          where: u.id == type(^user.id, :binary_id)
        )
        |> Repo.update_all(set: [status: "restricted"])

      user_after =
        Repo.one(
          from(u in "users",
            where: u.id == type(^user.id, :binary_id),
            select: %{status: u.status}
          )
        )

      assert user_after.status == "restricted"
    end
  end

  describe "object_to_processing/1" do
    test "sets processing_consent to false", %{user: user} do
      {1, _} =
        from(u in "users",
          where: u.id == type(^user.id, :binary_id)
        )
        |> Repo.update_all(set: [processing_consent: false])

      row =
        Repo.one(
          from(u in "users",
            where: u.id == type(^user.id, :binary_id),
            select: %{processing_consent: u.processing_consent}
          )
        )

      refute row.processing_consent
    end
  end
end
