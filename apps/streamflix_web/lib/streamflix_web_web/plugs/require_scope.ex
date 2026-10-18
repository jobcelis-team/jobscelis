defmodule StreamflixWebWeb.Plugs.RequireScope do
  @moduledoc """
  Plug that checks if the current API key has the required scope.
  Usage: plug RequireScope, "events:read"
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(required_scope) when is_binary(required_scope), do: required_scope

  def call(conn, required_scope) do
    api_key = conn.assigns[:current_api_key]
    scopes = (api_key && api_key.scopes) || ["*"]

    if "*" in scopes or required_scope in scopes do
      conn
    else
      # Same error shape as the rest of the API, naming the scope the key lacks
      conn
      |> put_status(:forbidden)
      |> json(%{error: "API key is missing the #{required_scope} scope"})
      |> halt()
    end
  end
end
