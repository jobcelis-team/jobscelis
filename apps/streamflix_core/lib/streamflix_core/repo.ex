defmodule StreamflixCore.Repo do
  use Ecto.Repo,
    otp_app: :streamflix_core,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Dynamically loads the repository url from the DATABASE_URL environment variable.
  """
  def init(_type, config) do
    {:ok, Keyword.put(config, :url, System.get_env("DATABASE_URL") || config[:url])}
  end
end
