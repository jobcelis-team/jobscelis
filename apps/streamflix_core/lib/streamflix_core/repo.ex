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

  @doc """
  Like `get/2` for binary-UUID primary keys, but returns nil for ids that are
  not valid UUIDs (instead of raising Ecto.Query.CastError, i.e. a 500 for
  requests such as GET /api/v1/webhooks/abc).
  """
  def get_uuid(queryable, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> get(queryable, uuid)
      :error -> nil
    end
  end
end
