defmodule StreamflixWebWeb.Plugs.ApiMethodOverride do
  @moduledoc """
  Honours `X-HTTP-Method-Override` on POST requests to `/api/`.

  `Plug.MethodOverride` only reads a `_method` body field. Clients whose HTTP
  stack cannot send PATCH (the Java SDK uses `HttpURLConnection`) send a POST
  with this header instead; without it every update returned 404. Limited to
  the API, which authenticates with tokens rather than cookies.
  """
  @behaviour Plug

  @allowed ~w(PATCH PUT DELETE)

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{method: "POST", path_info: ["api" | _]} = conn, _opts) do
    case Plug.Conn.get_req_header(conn, "x-http-method-override") do
      [method | _] ->
        method = String.upcase(method)
        if method in @allowed, do: %{conn | method: method}, else: conn

      [] ->
        conn
    end
  end

  def call(conn, _opts), do: conn
end
