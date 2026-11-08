defmodule StreamflixWebWeb.Plugs.RateLimitTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias StreamflixWebWeb.Plugs.RateLimit

  @rules [
    {"POST", "/login", 2},
    {"POST", "/mfa/verify", 3},
    {"POST", "/mfa/verify-backup", 1},
    {"POST", "/reset-password/", 2}
  ]

  # Each test gets its own client IP, so buckets never leak between tests
  defp unique_ip do
    n = System.unique_integer([:positive])
    "10.#{rem(div(n, 65_536), 256)}.#{rem(div(n, 256), 256)}.#{rem(n, 256)}"
  end

  # Builds the conn the way the HTTP server does for a raw request target:
  # request_path keeps every slash, path_info drops empty segments. (Plug.Test
  # would parse "//login" as a URI authority, so the path is set by hand.)
  defp raw_conn(method, path, ip) do
    %{conn(method, "/") | request_path: path, path_info: String.split(path, "/", trim: true)}
    |> Plug.Conn.put_req_header("x-forwarded-for", ip)
  end

  defp request(method, path, ip) do
    opts = RateLimit.init(path_rules: @rules, window_sec: 60)
    method |> raw_conn(path, ip) |> RateLimit.call(opts)
  end

  test "/login, /login/ and //login share one bucket" do
    ip = unique_ip()

    refute request("POST", "/login", ip).halted
    refute request("POST", "/login/", ip).halted

    conn = request("POST", "//login", ip)
    assert conn.halted
    assert conn.status == 429

    assert request("POST", "/login//", ip).status == 429
  end

  # Every HTTP connection runs in its own process; the counters must survive
  # them, or each new connection would start with a fresh bucket.
  test "buckets survive the processes that made the requests" do
    ip = unique_ip()

    for _ <- 1..2 do
      Task.async(fn -> refute request("POST", "/login", ip).halted end) |> Task.await()
    end

    task = Task.async(fn -> request("POST", "/login", ip).status end)
    assert Task.await(task) == 429
  end

  test "a prefix rule shares one bucket across every token" do
    ip = unique_ip()

    refute request("POST", "/reset-password/aaa", ip).halted
    refute request("POST", "/reset-password/bbb", ip).halted
    assert request("POST", "//reset-password/ccc/", ip).status == 429
  end

  test "rules match on segment boundaries, not raw prefixes" do
    ip = unique_ip()

    # /mfa/verify-backup has its own (stricter) rule and bucket
    refute request("POST", "/mfa/verify-backup", ip).halted
    assert request("POST", "/mfa/verify-backup", ip).status == 429
    refute request("POST", "/mfa/verify", ip).halted

    # /loginx is not /login
    for _ <- 1..5, do: refute(request("POST", "/loginx", ip).halted)
  end

  test "other methods are not limited by the rule" do
    ip = unique_ip()
    for _ <- 1..5, do: refute(request("GET", "/login", ip).halted)
  end

  test "API paths get a JSON 429 even with extra slashes" do
    ip = unique_ip()
    opts = RateLimit.init(path_rules: [{"POST", "/api/v1/auth/login", 1}], window_sec: 60)

    call = fn path -> "POST" |> raw_conn(path, ip) |> RateLimit.call(opts) end

    refute call.("/api/v1/auth/login").halted
    conn = call.("//api/v1/auth/login///")
    assert conn.status == 429
    assert ["application/json" <> _] = Plug.Conn.get_resp_header(conn, "content-type")
  end
end
