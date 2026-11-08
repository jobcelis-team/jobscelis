defmodule StreamflixWebWeb.Plugs.RateLimit do
  @moduledoc """
  Rate limiting por IP usando ETS. Evita abuso (DoS, fuerza bruta) en login, registro y API auth.
  """
  import Plug.Conn

  @table __MODULE__
  @window_sec 60

  def init(opts) do
    max = Keyword.get(opts, :max, 10)
    window = Keyword.get(opts, :window_sec, @window_sec)
    key_suffix = Keyword.get(opts, :key, nil)
    path_rules = Keyword.get(opts, :path_rules, [])
    %{max: max, window_sec: window, key_suffix: key_suffix, path_rules: path_rules}
  end

  def call(conn, %{
        max: max,
        window_sec: window_sec,
        key_suffix: key_suffix,
        path_rules: path_rules
      }) do
    if path_rules != [] do
      case path_match(conn, path_rules) do
        nil ->
          conn

        {max, key_suffix} ->
          maybe_cleanup_expired(@table, window_sec)
          ip = StreamflixWebWeb.Plugs.ClientIp.get_client_ip(conn)
          key = {ip, key_suffix}
          now = System.system_time(:second)
          apply_limit(conn, key, now, window_sec, max)
      end
    else
      maybe_cleanup_expired(@table, window_sec)
      key_suffix = key_suffix || "default"
      ip = StreamflixWebWeb.Plugs.ClientIp.get_client_ip(conn)
      key = {ip, key_suffix}
      now = System.system_time(:second)
      apply_limit(conn, key, now, window_sec, max)
    end
  end

  # The 429 body is a fixed message, sent as JSON (API) or text/plain.
  # sobelow_skip ["XSS.ContentType", "XSS.SendResp"]
  defp apply_limit(conn, key, now, window_sec, max) do
    case check_and_inc(@table, key, now, window_sec, max) do
      :allow ->
        conn

      :limit_exceeded ->
        api? = String.starts_with?(normalized_path(conn), "/api/")

        body =
          if api? do
            Jason.encode!(%{error: "Too many requests. Try again in a minute."})
          else
            "Demasiadas peticiones. Intenta de nuevo en un minuto."
          end

        content_type =
          if api?,
            do: "application/json",
            else: "text/plain"

        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("retry-after", "60")
        |> send_resp(429, body)
        |> halt()
    end
  end

  # Matches against the path Plug routes on (`path_info`, empty segments
  # dropped), not the raw `request_path`: `/login/`, `//login` and `/login`
  # reach the same action and must share one bucket. The bucket is keyed by
  # the matched rule, never by the request path, so path variations (or a
  # different token in `/reset-password/:token`) cannot open fresh buckets.
  defp path_match(conn, path_rules) do
    method = conn.method
    path = normalized_path(conn)

    case Enum.find(path_rules, fn {m, p, _} -> m == method and rule_matches?(p, path) end) do
      {m, p, max} -> {max, p <> m}
      nil -> nil
    end
  end

  @doc false
  def normalized_path(%Plug.Conn{path_info: path_info}), do: "/" <> Enum.join(path_info, "/")

  # A rule ending in "/" is a prefix rule ("/reset-password/" covers every
  # token). Otherwise it matches the path itself or anything below it on a
  # segment boundary ("/mfa/verify" does not cover "/mfa/verify-backup").
  defp rule_matches?(rule, path) do
    if String.ends_with?(rule, "/") do
      String.starts_with?(path, rule)
    else
      path == rule or String.starts_with?(path, rule <> "/")
    end
  end

  # update_counter is atomic, so concurrent requests cannot both slip under
  # the limit the way a separate lookup + increment would allow.
  defp check_and_inc(table, key, now, window_sec, max) do
    case :ets.lookup(table, key) do
      [{^key, _count, started}] when now - started <= window_sec ->
        if :ets.update_counter(table, key, {2, 1}) > max, do: :limit_exceeded, else: :allow

      _ ->
        :ets.insert(table, {key, 1, now})
        :allow
    end
  end

  # Probabilistic cleanup (~1% of requests) to prevent unbounded ETS growth
  defp maybe_cleanup_expired(table, window_sec) do
    if :rand.uniform(100) == 1 do
      now = System.system_time(:second)
      expire_before = now - window_sec * 2
      :ets.select_delete(table, [{{:"$1", :"$2", :"$3"}, [{:<, :"$3", expire_before}], [true]}])
    end
  end
end

defmodule StreamflixWebWeb.Plugs.RateLimit.Table do
  @moduledoc false
  # The table must outlive any single request. Created from the request
  # process it would die with that connection, resetting every counter, so it
  # is owned by a supervised process started before the endpoint.
  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @impl true
  def init(nil) do
    :ets.new(StreamflixWebWeb.Plugs.RateLimit, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, nil}
  end
end
