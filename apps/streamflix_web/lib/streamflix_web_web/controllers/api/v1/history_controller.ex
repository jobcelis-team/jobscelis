defmodule StreamflixWebWeb.Api.V1.HistoryController do
  use StreamflixWebWeb, :controller

  alias StreamflixAccounts
  alias StreamflixCatalog

  action_fallback StreamflixWebWeb.FallbackController

  @doc """
  Gets the user's watch history.
  """
  def index(conn, params) do
    profile_id = params["profile_id"]
    limit = String.to_integer(params["limit"] || "50")

    history = StreamflixAccounts.get_watch_history(profile_id, limit: limit)

    # Enrich with content data
    enriched = Enum.map(history, fn item ->
      content = StreamflixCatalog.get_content(item.content_id)
      Map.merge(item, %{content: content && content_json(content)})
    end)

    json(conn, %{
      history: enriched
    })
  end

  @doc """
  Gets content the user can continue watching.
  """
  def continue_watching(conn, params) do
    profile_id = params["profile_id"]

    history = StreamflixAccounts.get_watch_history(profile_id, limit: 20)
    
    # Filter to only incomplete items
    continue = history
    |> Enum.filter(fn item -> 
      item.progress > 0.05 and item.progress < 0.95 and not item.completed
    end)
    |> Enum.take(10)

    # Enrich with content data
    enriched = Enum.map(continue, fn item ->
      content = StreamflixCatalog.get_content(item.content_id)
      %{
        content: content && content_json(content),
        position_seconds: item.position_seconds,
        progress: item.progress,
        last_watched_at: item.last_watched_at
      }
    end)

    json(conn, %{
      continue_watching: enriched
    })
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
