defmodule StreamflixWebWeb.Plugs.ApiKeyAuth do
  @moduledoc """
  Authenticates API requests using API Key (Bearer or X-Api-Key).
  Assigns current_project and current_api_key when valid.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    with token when is_binary(token) and token != "" <- get_api_key(conn),
         api_key when not is_nil(api_key) <- StreamflixCore.Platform.verify_api_key("", token) do
      conn
      |> assign(:current_project, api_key.project)
      |> assign(:current_api_key, api_key)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> put_view(json: StreamflixWebWeb.ErrorJSON)
        |> render(:"401")
        |> halt()
    end
  end

  defp get_api_key(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ ->
        case get_req_header(conn, "x-api-key") do
          [token] -> token
          _ -> nil
        end
    end
  end
end
