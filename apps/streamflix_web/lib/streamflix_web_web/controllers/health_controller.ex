defmodule StreamflixWebWeb.HealthController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixWebWeb.Schemas

  tags ["System"]
  security []

  operation :index,
    summary: "Check system health status",
    responses: [
      ok: {"System healthy", "application/json", Schemas.HealthResponse},
      service_unavailable: {"System unhealthy", "application/json", Schemas.HealthResponse}
    ]

  def index(conn, _params) do
    db_status =
      try do
        StreamflixCore.Repo.query!("SELECT 1")
        "ok"
      rescue
        _ -> "error"
      end

    status = if db_status == "ok", do: 200, else: 503

    conn
    |> put_status(status)
    |> json(%{
      status: if(status == 200, do: "healthy", else: "unhealthy"),
      database: db_status,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end
end
