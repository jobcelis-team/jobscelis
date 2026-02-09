defmodule StreamflixWebWeb.Plugs.SessionWithConfig do
  @moduledoc """
  Wrapper de Plug.Session que usa el signing_salt desde configuración (env SESSION_SIGNING_SALT).
  Así en producción puedes rotar el salt sin recompilar.
  """

  @base_opts [
    store: :cookie,
    key: "_streamflix_web_key",
    same_site: "Lax",
    max_age: 2_592_000
  ]
  @default_salt "Ig7MA6EW"

  def init(_opts), do: nil

  def call(conn, _opts) do
    salt =
      Application.get_env(:streamflix_web, StreamflixWebWeb.Endpoint, [])[:session_signing_salt] ||
        @default_salt

    opts = Keyword.put(@base_opts, :signing_salt, salt)
    Plug.Session.call(conn, Plug.Session.init(opts))
  end
end
