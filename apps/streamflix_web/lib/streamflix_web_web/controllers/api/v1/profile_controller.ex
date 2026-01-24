defmodule StreamflixWebWeb.Api.V1.ProfileController do
  use StreamflixWebWeb, :controller

  alias StreamflixAccounts

  action_fallback StreamflixWebWeb.FallbackController

  @doc """
  Lists all profiles for the current user.
  """
  def index(conn, _params) do
    user = conn.assigns.current_user
    profiles = StreamflixAccounts.list_profiles(user.id)

    json(conn, %{
      profiles: Enum.map(profiles, &profile_json/1)
    })
  end

  @doc """
  Gets a specific profile.
  """
  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    
    case StreamflixAccounts.get_profile(id) do
      nil ->
        {:error, :not_found}

      profile ->
        if profile.user_id == user.id do
          json(conn, %{profile: profile_json(profile)})
        else
          {:error, :forbidden}
        end
    end
  end

  @doc """
  Creates a new profile.
  """
  def create(conn, params) do
    user = conn.assigns.current_user
    
    attrs = %{
      name: params["name"],
      avatar_url: params["avatar_url"],
      is_kids: params["is_kids"] || false
    }

    case StreamflixAccounts.create_profile(user.id, attrs) do
      {:ok, profile} ->
        conn
        |> put_status(:created)
        |> json(%{profile: profile_json(profile)})

      {:error, :max_profiles_reached} ->
        {:error, "Maximum number of profiles reached for your plan"}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a profile.
  """
  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    case StreamflixAccounts.get_profile(id) do
      nil ->
        {:error, :not_found}

      profile ->
        if profile.user_id == user.id do
          attrs = Map.take(params, ["name", "avatar_url", "is_kids"])
          
          case StreamflixAccounts.update_profile(profile, attrs) do
            {:ok, updated_profile} ->
              json(conn, %{profile: profile_json(updated_profile)})

            {:error, changeset} ->
              {:error, changeset}
          end
        else
          {:error, :forbidden}
        end
    end
  end

  @doc """
  Deletes a profile.
  """
  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case StreamflixAccounts.get_profile(id) do
      nil ->
        {:error, :not_found}

      profile ->
        if profile.user_id == user.id do
          case StreamflixAccounts.delete_profile(profile) do
            {:ok, _} ->
              send_resp(conn, :no_content, "")

            {:error, :cannot_delete_last_profile} ->
              {:error, "Cannot delete the last profile"}

            {:error, reason} ->
              {:error, reason}
          end
        else
          {:error, :forbidden}
        end
    end
  end

  defp profile_json(profile) do
    %{
      id: profile.id,
      name: profile.name,
      avatar_url: profile.avatar_url,
      is_kids: profile.is_kids,
      created_at: profile.inserted_at
    }
  end
end
