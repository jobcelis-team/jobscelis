defmodule StreamflixWebWeb.Api.V1.MyListController do
  use StreamflixWebWeb, :controller

  alias StreamflixCatalog
  alias StreamflixAccounts

  action_fallback StreamflixWebWeb.FallbackController

  @doc """
  Gets the user's list.
  """
  def index(conn, params) do
    user = conn.assigns.current_user
    profile_id = get_profile_id(user.id, params["profile_id"])
    
    items = if profile_id do
      StreamflixCatalog.get_my_list(profile_id)
    else
      []
    end

    json(conn, %{
      items: Enum.map(items, &content_json/1)
    })
  end

  @doc """
  Adds content to the user's list.
  """
  def add(conn, %{"content_id" => content_id} = params) do
    user = conn.assigns.current_user
    profile_id = get_profile_id(user.id, params["profile_id"])

    if profile_id do
      case StreamflixCatalog.add_to_my_list(profile_id, content_id) do
        {:ok, _} ->
          conn
          |> put_status(:created)
          |> json(%{success: true, message: "Added to My List"})

        {:error, :already_in_list} ->
          json(conn, %{success: true, message: "Already in My List"})

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :no_profile}
    end
  end

  @doc """
  Removes content from the user's list.
  """
  def remove(conn, %{"content_id" => content_id} = params) do
    user = conn.assigns.current_user
    profile_id = get_profile_id(user.id, params["profile_id"])

    if profile_id do
      case StreamflixCatalog.remove_from_my_list(profile_id, content_id) do
        {:ok, _} ->
          send_resp(conn, :no_content, "")

        {:error, :not_in_list} ->
          send_resp(conn, :no_content, "")

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :no_profile}
    end
  end

  defp get_profile_id(_user_id, profile_id) when is_binary(profile_id), do: profile_id
  defp get_profile_id(user_id, _) do
    # Get first profile for user
    profiles = StreamflixAccounts.list_profiles(user_id)
    case List.first(profiles) do
      nil -> nil
      profile -> profile.id
    end
  end

  defp content_json(content) do
    %{
      id: content.id,
      title: content.title,
      type: content.type,
      poster_url: content.poster_url,
      backdrop_url: content.backdrop_url,
      year: content.release_year,
      rating: content.rating,
      added_at: content.added_at
    }
  end
end
