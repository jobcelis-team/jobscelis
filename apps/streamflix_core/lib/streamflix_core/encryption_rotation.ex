defmodule StreamflixCore.EncryptionRotation do
  @moduledoc """
  Re-encrypts every Cloak field with the Vault's current `:default` cipher and
  recomputes every HMAC lookup hash with the current HMAC secret.

  Used to rotate `CLOAK_KEY` / `HMAC_SECRET` (see `config/runtime.exs`): deploy
  with the new key as `CLOAK_KEY` and the old one as `CLOAK_KEY_RETIRED` (so old
  ciphertexts can still be read), set the new `HMAC_SECRET`, then run
  `bin/streamflix eval "StreamflixCore.Release.rotate_encryption()"`.

  Works on the tables directly (no schemas) because some of them belong to
  other umbrella apps. Each batch is updated in its own transaction; running it
  twice is harmless.
  """

  import Ecto.Query

  alias StreamflixCore.{Hashed, Repo, Vault}

  @batch_size 500

  # table => encrypted columns
  @encrypted [
    {"users", [:email, :name, :mfa_secret]},
    {"webhooks", [:secret_encrypted]},
    {"consents", [:ip_address]},
    {"sandbox_requests", [:ip]},
    {"audit_logs", [:ip_address, :user_agent]}
  ]

  @doc "Rotates all tables. Returns `%{table => rows_updated}`."
  def run(opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @batch_size)

    Map.new(@encrypted, fn {table, columns} ->
      {table, rotate_table(table, columns, batch_size)}
    end)
  end

  defp rotate_table(table, columns, batch_size) do
    hash_columns = hash_columns(table)
    selected = [:id | columns ++ hash_columns]
    rotate_batches(table, columns, selected, batch_size, nil, 0)
  end

  defp rotate_batches(table, columns, selected, batch_size, last_id, count) do
    rows =
      table
      |> from(as: :t)
      |> after_id(last_id)
      |> order_by([t], asc: t.id)
      |> limit(^batch_size)
      |> select([t], map(t, ^selected))
      |> Repo.all()

    if rows == [] do
      count
    else
      {:ok, _} =
        Repo.transaction(fn ->
          Enum.each(rows, &update_row(table, columns, &1))
        end)

      next_id = rows |> List.last() |> Map.fetch!(:id) |> load_uuid()
      rotate_batches(table, columns, selected, batch_size, next_id, count + length(rows))
    end
  end

  defp after_id(query, nil), do: query
  defp after_id(query, id), do: where(query, [t], t.id > type(^id, Ecto.UUID))

  defp update_row(table, columns, row) do
    plain = Map.new(columns, fn col -> {col, decrypt(row[col])} end)

    changes =
      Enum.map(columns, fn col -> {col, encrypt(plain[col])} end) ++
        hash_changes(table, plain, row)

    id = load_uuid(row.id)

    from(t in table, where: t.id == type(^id, Ecto.UUID))
    |> Repo.update_all(set: changes)
  end

  # Lookup hashes are derived from a decrypted column, exactly as the schemas do
  defp hash_columns("users"), do: [:email_hash]
  defp hash_columns("audit_logs"), do: [:ip_hash]
  defp hash_columns(_), do: []

  defp hash_changes("users", %{email: email}, _row) when is_binary(email),
    do: [email_hash: hmac(String.downcase(email))]

  defp hash_changes("audit_logs", %{ip_address: ip}, %{ip_hash: old})
       when is_binary(ip) and ip != "" and not is_nil(old),
       do: [ip_hash: hmac(String.trim(ip))]

  defp hash_changes(_table, _plain, _row), do: []

  defp decrypt(nil), do: nil
  defp decrypt(ciphertext), do: Vault.decrypt!(ciphertext)

  defp encrypt(nil), do: nil
  defp encrypt(plaintext), do: Vault.encrypt!(plaintext)

  defp hmac(value) do
    {:ok, hash} = Hashed.HMAC.dump(value)
    hash
  end

  defp load_uuid(<<_::128>> = raw), do: Ecto.UUID.load!(raw)
  defp load_uuid(id) when is_binary(id), do: id
end
