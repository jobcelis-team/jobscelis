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

  @doc "POST /api/v1/me/restrict — Restrict processing (Art. 18)"
  def restrict(conn, %{"password" => password}) do
    user = StreamflixAccounts.get_user(conn.assigns[:current_user_id])

    case StreamflixAccounts.restrict_user(user, password) do
      {:ok, updated} ->
        StreamflixCore.Audit.record("gdpr.processing_restricted",
          user_id: updated.id,
          resource_type: "user",
          resource_id: updated.id,
          metadata: %{reason: "user_requested"}
        )

        json(conn, %{status: "restricted", restricted_at: updated.restricted_at})

      {:error, :wrong_password} ->
        conn |> put_status(:unauthorized) |> json(%{error: "Invalid password"})

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not restrict processing"})
    end
  end

  def restrict(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "Password required"})
  end

  @doc "DELETE /api/v1/me/restrict — Lift restriction"
  def lift_restriction(conn, _params) do
    user = StreamflixAccounts.get_user(conn.assigns[:current_user_id])

    case StreamflixAccounts.lift_restriction(user) do
      {:ok, updated} ->
        StreamflixCore.Audit.record("gdpr.restriction_lifted",
          user_id: updated.id,
          resource_type: "user",
          resource_id: updated.id
        )

        json(conn, %{status: "active"})

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not lift restriction"})
    end
  end

  @doc "POST /api/v1/me/object — Object to processing (Art. 21)"
  def object(conn, _params) do
    user = StreamflixAccounts.get_user(conn.assigns[:current_user_id])

    case StreamflixAccounts.object_to_processing(user) do
      {:ok, updated} ->
        StreamflixCore.Audit.record("gdpr.processing_objection",
          user_id: updated.id,
          resource_type: "user",
          resource_id: updated.id
        )

        json(conn, %{processing_consent: false})

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not register objection"})
    end
  end

  @doc "DELETE /api/v1/me/object — Restore processing consent"
  def restore_consent(conn, _params) do
    user = StreamflixAccounts.get_user(conn.assigns[:current_user_id])

    case StreamflixAccounts.restore_processing_consent(user) do
      {:ok, updated} ->
        StreamflixCore.Audit.record("gdpr.processing_consent_restored",
          user_id: updated.id,
          resource_type: "user",
          resource_id: updated.id
        )

        json(conn, %{processing_consent: true})

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not restore consent"})
    end
  end
end
