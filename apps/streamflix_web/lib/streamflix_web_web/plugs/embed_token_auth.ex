defmodule StreamflixWebWeb.Plugs.EmbedTokenAuth do
  @moduledoc """
  Authenticates embed portal requests using embed tokens.
  Tokens are passed via Authorization Bearer header, X-Embed-Token header,
  or `token` query parameter.
  Assigns current_project and current_embed_token when valid.
  Also validates Origin header against allowed_origins if configured.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    with raw when is_binary(raw) and raw != "" <- extract_token(conn),
         %{} = token when not is_nil(token) <- StreamflixCore.EmbedTokens.verify(raw),
         :ok <- check_origin(conn, token) do
      conn
      |> assign(:current_project, token.project)
      |> assign(:current_embed_token, token)
    else
      :origin_not_allowed ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Origin not allowed"})
        |> halt()

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid or expired embed token"})
        |> halt()
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        token

      _ ->
        case get_req_header(conn, "x-embed-token") do
          [token] -> token
          _ -> conn.query_params["token"]
        end
    end
  end

  defp check_origin(conn, token) do
    allowed = token.allowed_origins || []

    if allowed == [] do
      :ok
    else
      case get_req_header(conn, "origin") do
        [origin] -> if origin in allowed, do: :ok, else: :origin_not_allowed
        _ -> :ok
      end
    end
  end
end
