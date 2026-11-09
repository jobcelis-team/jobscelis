defmodule StreamflixWebWeb.HealthController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixWebWeb.Schemas

  tags(["System"])
  security([])

  operation(:index,
    summary: "Check system health status",
    responses: [
      ok: {"System healthy", "application/json", Schemas.HealthResponse},
      service_unavailable: {"System unhealthy", "application/json", Schemas.HealthResponse}
    ]
  )

  def index(conn, _params) do
    db = check_database()
    oban = check_oban()
    cache = check_cache()

    {status_code, status_label} =
      cond do
        db != "ok" -> {503, "unhealthy"}
        oban != "ok" or cache != "ok" -> {200, "degraded"}
        true -> {200, "healthy"}
      end

    conn
    |> put_status(status_code)
    |> json(%{
      status: status_label,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # /health is public: the database result is shared for a few seconds, so a
  # flood of requests costs at most one query per window instead of holding
  # pool connections.
  @db_check_ttl :timer.seconds(5)

  defp check_database do
    case Cachex.get(:platform_cache, :health_db_check) do
      {:ok, result} when is_binary(result) ->
        result

      _ ->
        result = ping_database()
        Cachex.put(:platform_cache, :health_db_check, result, expire: @db_check_ttl)
        result
    end
  end

  defp ping_database do
    try do
      StreamflixCore.Repo.query!("SELECT 1")
      "ok"
    rescue
      _ -> "error"
    end
  end

  defp check_oban do
    try do
      %{running: _} = Oban.check_queue(queue: :default)
      "ok"
    rescue
      _ -> "error"
    end
  end

  defp check_cache do
    try do
      case Cachex.size(:platform_cache) do
        {:ok, _count} -> "ok"
        _ -> "error"
      end
    rescue
      _ -> "error"
    end
  end
end
