defmodule StreamflixCore.EncryptionRotationTest do
  # Swaps the global Vault/HMAC configuration: must not run concurrently
  use StreamflixCore.DataCase, async: false

  alias StreamflixCore.{EncryptionRotation, Vault}
  alias StreamflixCore.Schemas.{AuditLog, Webhook}

  @gcm Cloak.Ciphers.AES.GCM

  setup do
    vault_env = Application.get_env(:streamflix_core, Vault)
    hmac_env = Application.get_env(:streamflix_core, StreamflixCore.Hashed.HMAC)

    on_exit(fn ->
      Application.put_env(:streamflix_core, Vault, vault_env)
      Application.put_env(:streamflix_core, StreamflixCore.Hashed.HMAC, hmac_env)
      restart_vault()
    end)

    %{old_ciphers: vault_env[:ciphers]}
  end

  defp restart_vault do
    :ok = Supervisor.terminate_child(StreamflixCore.Supervisor, Vault)
    {:ok, _} = Supervisor.restart_child(StreamflixCore.Supervisor, Vault)
  end

  defp use_keys(ciphers, hmac_secret) do
    Application.put_env(:streamflix_core, Vault, ciphers: ciphers)

    Application.put_env(:streamflix_core, StreamflixCore.Hashed.HMAC,
      algorithm: :sha512,
      secret: hmac_secret
    )

    restart_vault()
  end

  defp hmac(secret, value), do: :crypto.mac(:hmac, :sha512, secret, value)

  test "re-encrypts with the new key and recomputes lookup hashes", %{old_ciphers: old} do
    project = insert(:project)

    {:ok, webhook} =
      Repo.insert(
        Webhook.changeset(%Webhook{}, %{
          project_id: project.id,
          url: "https://example.com/h",
          secret_encrypted: "whsec_123"
        })
      )

    {:ok, audit} =
      Repo.insert(AuditLog.changeset(%AuditLog{}, %{action: "test", ip_address: "203.0.113.9"}))

    user_id = Ecto.UUID.generate()

    Repo.insert_all("users", [
      %{
        id: Ecto.UUID.dump!(user_id),
        email: Vault.encrypt!("Rotate@Example.com"),
        name: Vault.encrypt!("Rotate Me"),
        email_hash: "old-hash",
        password_hash: "x",
        status: "active",
        role: "user",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])

    {_, {_, old_opts}} = List.keyfind(old, :default, 0)
    new_key = :crypto.strong_rand_bytes(32)
    new_hmac = "new-hmac-secret-for-test"

    # New default key, old key kept only to read existing ciphertexts
    use_keys(
      [
        default: {@gcm, tag: "AES.GCM.V2", key: new_key, iv_length: 12},
        retired: {@gcm, Keyword.put(old_opts, :tag, "AES.GCM.V1")}
      ],
      new_hmac
    )

    result = EncryptionRotation.run(batch_size: 1)
    assert result["webhooks"] == 1
    assert result["users"] == 1

    # Without the retired key, everything must still decrypt
    use_keys([default: {@gcm, tag: "AES.GCM.V2", key: new_key, iv_length: 12}], new_hmac)

    assert Repo.get!(Webhook, webhook.id).secret_encrypted == "whsec_123"
    assert Repo.get!(AuditLog, audit.id).ip_address == "203.0.113.9"
    assert Repo.get!(AuditLog, audit.id).ip_hash == hmac(new_hmac, "203.0.113.9")

    [user] =
      Repo.all(
        from(u in "users",
          where: u.id == type(^user_id, Ecto.UUID),
          select: %{email: u.email, name: u.name, email_hash: u.email_hash}
        )
      )

    assert Vault.decrypt!(user.email) == "Rotate@Example.com"
    assert Vault.decrypt!(user.name) == "Rotate Me"
    assert user.email_hash == hmac(new_hmac, "rotate@example.com")
  end
end
