defmodule StreamflixWebWeb.Plugs.NoIndex do
  @moduledoc """
  Adds X-Robots-Tag: noindex, nofollow header to prevent search engines
  from indexing private routes (platform, admin, account).
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    put_resp_header(conn, "x-robots-tag", "noindex, nofollow")
  end
end
