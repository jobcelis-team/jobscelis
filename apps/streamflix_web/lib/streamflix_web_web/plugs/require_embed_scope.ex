defmodule StreamflixWebWeb.Plugs.RequireEmbedScope do
  @moduledoc """
  Checks that the current embed token has the required scope.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(scope) when is_binary(scope), do: scope

  def call(conn, required_scope) do
    token = conn.assigns[:current_embed_token]

    if token && StreamflixCore.EmbedTokens.has_scope?(token, required_scope) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient scope: #{required_scope}"})
      |> halt()
    end
  end
end
