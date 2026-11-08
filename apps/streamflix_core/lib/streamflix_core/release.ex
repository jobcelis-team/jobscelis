defmodule StreamflixCore.Release do
  @app :streamflix_core

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
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
