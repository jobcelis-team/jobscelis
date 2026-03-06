defmodule StreamflixWebWeb.Plugs.ApiVersion do
  @moduledoc """
  Adds API versioning headers to all API responses.

  Headers added:
  - `X-API-Version` — current API version (e.g. "1")
  - `Deprecation` — present only when the requested version is deprecated
  - `Sunset` — date when the deprecated version will be removed
  """
  import Plug.Conn

  @current_version "1"

  def init(opts), do: opts

  def call(%{request_path: "/api/v1/" <> _} = conn, _opts) do
    conn
    |> put_resp_header("x-api-version", @current_version)
  end

  def call(conn, _opts), do: conn
end
