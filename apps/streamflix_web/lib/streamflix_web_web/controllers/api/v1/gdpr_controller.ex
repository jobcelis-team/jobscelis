defmodule StreamflixWebWeb.Api.V1.GDPRController do
  use StreamflixWebWeb, :controller

  alias StreamflixCore.GDPR
  alias StreamflixAccounts

  @doc "GET /api/v1/me/data — Export all personal data (DSAR)"
  def export_my_data(conn, _params) do
    user_id = conn.assigns[:current_user_id]
    user = StreamflixAccounts.get_user(user_id)

    if user do
      data = GDPR.collect_user_data(user)
      json(conn, %{data: data})
    else
      conn |> put_status(:unauthorized) |> json(%{error: "Unauthorized"})
    end
  end
end
