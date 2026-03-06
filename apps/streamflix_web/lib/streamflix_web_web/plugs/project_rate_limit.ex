defmodule StreamflixWebWeb.Plugs.ProjectRateLimit do
  @moduledoc """
  Per-project rate limiting plug using Cachex atomic increments.

  Checks `conn.assigns.current_project` and enforces the project's
  `rate_limit_api_calls_per_minute` limit. If no project is assigned
  (e.g., auth failed), the plug is skipped.

  Rate limit headers are added to all responses:
  - `X-RateLimit-Limit` — max requests per minute
  - `X-RateLimit-Remaining` — remaining requests in current window
  - `X-RateLimit-Reset` — Unix timestamp when the window resets
  - `Retry-After` — seconds until reset (only on 429)
  """
  import Plug.Conn

  @cache :platform_cache

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_project] do
      nil ->
        conn

      project ->
        check_rate_limit(conn, project)
    end
  end

  defp check_rate_limit(conn, project) do
    project_id = project.id
    limit = project.rate_limit_api_calls_per_minute
    now = System.system_time(:second)
    minute_bucket = div(now, 60)
    cache_key = {:rate_limit, project_id, minute_bucket}
    reset_at = (minute_bucket + 1) * 60
    retry_after = max(reset_at - now, 1)

    case Cachex.incr(@cache, cache_key, 1, ttl: :timer.seconds(120)) do
      {:ok, count} ->
        remaining = max(limit - count, 0)

        if count > limit do
          conn
          |> put_rate_limit_headers(limit, 0, reset_at)
          |> put_resp_header("retry-after", Integer.to_string(retry_after))
          |> put_resp_content_type("application/json")
          |> send_resp(429, rate_limit_body(retry_after, limit))
          |> halt()
        else
          conn
          |> put_rate_limit_headers(limit, remaining, reset_at)
        end

      _error ->
        # If cache is unavailable, allow the request through
        conn
    end
  end

  defp put_rate_limit_headers(conn, limit, remaining, reset_at) do
    conn
    |> put_resp_header("x-ratelimit-limit", Integer.to_string(limit))
    |> put_resp_header("x-ratelimit-remaining", Integer.to_string(remaining))
    |> put_resp_header("x-ratelimit-reset", Integer.to_string(reset_at))
  end

  defp rate_limit_body(retry_after, limit) do
    Jason.encode!(%{
      error: "rate_limit_exceeded",
      retry_after: retry_after,
      limit: limit,
      remaining: 0
    })
  end
end
