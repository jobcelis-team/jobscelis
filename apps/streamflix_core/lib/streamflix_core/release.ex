defmodule StreamflixCore.Release do
  @app :streamflix_core

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Re-encrypts all Cloak fields and recomputes HMAC hashes with the current keys.
  See `StreamflixCore.EncryptionRotation` for the rotation procedure.
  """
  def rotate_encryption do
    load_app()
    {:ok, _} = Application.ensure_all_started(:cloak)

    for repo <- repos() do
      {:ok, result, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          {:ok, _vault} = StreamflixCore.Vault.start_link([])
          StreamflixCore.EncryptionRotation.run()
        end)

      IO.puts("rows re-encrypted per table: #{inspect(result)}")
    end
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)
  # Only load the app: with_repo starts the Repo it needs. Starting the whole
  # app here also started Oban (cron and queues), the scheduler and a health
  # check, which could run jobs against a schema still being migrated.
  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
