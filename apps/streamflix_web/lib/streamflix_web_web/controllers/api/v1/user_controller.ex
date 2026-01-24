defmodule StreamflixWebWeb.Api.V1.UserController do
  use StreamflixWebWeb, :controller

  alias StreamflixAccounts

  action_fallback StreamflixWebWeb.FallbackController

  @doc """
  Gets the current user's information.
  """
  def me(conn, _params) do
    user = conn.assigns.current_user
    subscription = StreamflixAccounts.get_active_subscription(user.id)

    json(conn, %{
      user: %{
        id: user.id,
        email: user.email,
        name: user.name,
        avatar_url: user.avatar_url,
        created_at: user.inserted_at
      },
      subscription: subscription && %{
        plan: subscription.plan,
        status: subscription.status,
        current_period_end: subscription.current_period_end
      }
    })
  end

  @doc """
  Updates the current user's information.
  """
  def update(conn, params) do
    user = conn.assigns.current_user
    
    allowed_params = Map.take(params, ["name", "avatar_url"])
    
    case StreamflixAccounts.update_user(user, allowed_params) do
      {:ok, updated_user} ->
        json(conn, %{
          user: %{
            id: updated_user.id,
            email: updated_user.email,
            name: updated_user.name,
            avatar_url: updated_user.avatar_url
          }
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
