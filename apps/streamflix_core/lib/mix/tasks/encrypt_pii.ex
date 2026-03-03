defmodule Mix.Tasks.EncryptPii do
  @moduledoc """
  Encrypts existing plaintext PII fields and populates the new encrypted columns.
  Run this AFTER the add_pii_encryption_columns migration and BEFORE removing plaintext columns.

  Usage:
    mix encrypt_pii
  """

  use Mix.Task
  import Ecto.Query

  @batch_size 100

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("Starting PII encryption migration...")

    encrypt_users()
    encrypt_audit_logs()
    encrypt_consents()
    encrypt_sandbox_requests()

    IO.puts("PII encryption migration complete!")
  end

  defp encrypt_users do
    IO.puts("\n→ Encrypting users...")
    repo = StreamflixCore.Repo

    "users"
    |> batch_stream(repo)
    |> Enum.each(fn rows ->
      Enum.each(rows, fn row ->
        email = row.email
        name = row.name

        changes =
          %{}
          |> maybe_put(:email_encrypted, email && encrypt(email))
          |> maybe_put(:email_hash, email && hmac_hash(String.downcase(email)))
          |> maybe_put(:name_encrypted, name && encrypt(name))

        if map_size(changes) > 0 do
          from(u in "users", where: u.id == ^row.id)
          |> repo.update_all(set: Enum.to_list(changes))
        end
      end)

      IO.write(".")
    end)

    IO.puts(" done")
  end

  defp encrypt_audit_logs do
    IO.puts("\n→ Encrypting audit_logs...")
    repo = StreamflixCore.Repo

    "audit_logs"
    |> batch_stream(repo)
    |> Enum.each(fn rows ->
      Enum.each(rows, fn row ->
        changes =
          %{}
          |> maybe_put(:ip_address_encrypted, row.ip_address && encrypt(row.ip_address))
          |> maybe_put(:user_agent_encrypted, row.user_agent && encrypt(row.user_agent))

        if map_size(changes) > 0 do
          from(a in "audit_logs", where: a.id == ^row.id)
          |> repo.update_all(set: Enum.to_list(changes))
        end
      end)

      IO.write(".")
    end)

    IO.puts(" done")
  end

  defp encrypt_consents do
    IO.puts("\n→ Encrypting consents...")
    repo = StreamflixCore.Repo

    "consents"
    |> batch_stream(repo)
    |> Enum.each(fn rows ->
      Enum.each(rows, fn row ->
        if row.ip_address do
          from(c in "consents", where: c.id == ^row.id)
          |> repo.update_all(set: [ip_address_encrypted: encrypt(row.ip_address)])
        end
      end)

      IO.write(".")
    end)

    IO.puts(" done")
  end

  defp encrypt_sandbox_requests do
    IO.puts("\n→ Encrypting sandbox_requests...")
    repo = StreamflixCore.Repo

    "sandbox_requests"
    |> batch_stream(repo)
    |> Enum.each(fn rows ->
      Enum.each(rows, fn row ->
        if row.ip do
          from(s in "sandbox_requests", where: s.id == ^row.id)
          |> repo.update_all(set: [ip_encrypted: encrypt(row.ip)])
        end
      end)

      IO.write(".")
    end)

    IO.puts(" done")
  end

  defp batch_stream(table, repo) do
    Stream.resource(
      fn -> nil end,
      fn
        :halt ->
          {:halt, nil}

        cursor ->
          query =
            from(r in table,
              select: r,
              order_by: [asc: r.id],
              limit: @batch_size
            )

          query =
            if cursor do
              from(r in query, where: r.id > ^cursor)
            else
              query
            end

          rows = repo.all(query)

          case rows do
            [] -> {:halt, nil}
            rows -> {[rows], List.last(rows).id}
          end
      end,
      fn _ -> :ok end
    )
  end

  defp encrypt(value) when is_binary(value) do
    {:ok, encrypted} = StreamflixCore.Encrypted.Binary.dump(value)
    encrypted
  end

  defp hmac_hash(value) when is_binary(value) do
    {:ok, hash} = StreamflixCore.Hashed.HMAC.dump(value)
    hash
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
