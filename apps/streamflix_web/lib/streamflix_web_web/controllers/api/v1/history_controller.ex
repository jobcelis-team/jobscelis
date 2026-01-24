defmodule StreamflixWebWeb.Api.V1.HistoryController do
  use StreamflixWebWeb, :controller

  alias StreamflixAccounts
  alias StreamflixCatalog

  action_fallback StreamflixWebWeb.FallbackController

  @doc """
  Gets the user's watch history.
  """
  def index(conn, params) do
    user = conn.assigns.current_user
    profile_id = get_profile_id(user.id, params["profile_id"])
    limit = String.to_integer(params["limit"] || "50")

    history = if profile_id do
      StreamflixCatalog.get_watch_history(profile_id, limit: limit)
    else
      []
    end

    # Enrich with content data
    enriched = Enum.map(history, fn item ->
      content = item.content || StreamflixCatalog.get_content(item.content_id)
      %{
        id: item.id,
        content: content && content_json(content),
        progress_seconds: item.progress_seconds,
        duration_seconds: item.duration_seconds,
        progress_percent: item.progress_percent,
        completed: item.completed,
        last_watched_at: item.last_watched_at
      }
    end)

    json(conn, %{
      history: enriched
    })
  end

  @doc """
  Gets content the user can continue watching.
  """
  def continue_watching(conn, params) do
    user = conn.assigns.current_user
    profile_id = get_profile_id(user.id, params["profile_id"])

    continue = if profile_id do
      StreamflixCatalog.get_continue_watching(profile_id, limit: 20)
    else
      []
    end

    # Enrich with content data
    enriched = Enum.map(continue, fn item ->
      content = item.content || StreamflixCatalog.get_content(item.content_id)
      %{
        content: content && content_json(content),
        progress_seconds: item.progress_seconds,
        duration_seconds: item.duration_seconds,
        progress_percent: item.progress_percent,
        last_watched_at: item.last_watched_at
      }
    end)

    json(conn, %{
      continue_watching: enriched
    })
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
      backdrop_url: content.backdrop_url
    }
  end
end
