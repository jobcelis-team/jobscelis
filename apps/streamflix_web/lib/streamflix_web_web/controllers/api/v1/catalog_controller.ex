defmodule StreamflixWebWeb.Api.V1.CatalogController do
  use StreamflixWebWeb, :controller

  alias StreamflixCatalog

  action_fallback StreamflixWebWeb.FallbackController

  @doc """
  Browse all content with optional filters.
  """
  def browse(conn, params) do
    opts = [
      page: String.to_integer(params["page"] || "1"),
      per_page: String.to_integer(params["per_page"] || "20"),
      type: params["type"]
    ]

    content = StreamflixCatalog.list_content(opts)

    conn
    |> put_status(:ok)
    |> json(%{
      data: Enum.map(content, &serialize_content/1),
      meta: %{
        page: opts[:page],
        per_page: opts[:per_page]
      }
    })
  end

  @doc """
  Browse content by genre.
  """
  def by_genre(conn, %{"genre" => genre_slug} = params) do
    opts = [
      page: String.to_integer(params["page"] || "1"),
      per_page: String.to_integer(params["per_page"] || "20")
    ]

    content = StreamflixCatalog.list_by_genre(genre_slug, opts)

    conn
    |> put_status(:ok)
    |> json(%{
      data: Enum.map(content, &serialize_content/1),
      genre: genre_slug,
      meta: %{
        page: opts[:page],
        per_page: opts[:per_page]
      }
    })
  end

  @doc """
  Get content details.
  """
  def show(conn, %{"id" => id}) do
    case StreamflixCatalog.get_content(id) do
      nil ->
        {:error, :not_found}

      content ->
        conn
        |> put_status(:ok)
        |> json(%{data: serialize_content_detail(content)})
    end
  end

  @doc """
  Get seasons for a series.
  """
  def seasons(conn, %{"id" => series_id}) do
    seasons = StreamflixCatalog.get_seasons(series_id)

    conn
    |> put_status(:ok)
    |> json(%{data: Enum.map(seasons, &serialize_season/1)})
  end

  @doc """
  Get episodes for a season.
  """
  def episodes(conn, %{"id" => _series_id, "season" => season_number} = params) do
    # Get season by series and number
    # Simplified - would need proper lookup
    season_id = params["season_id"]
    episodes = StreamflixCatalog.get_episodes(season_id)

    conn
    |> put_status(:ok)
    |> json(%{
      data: Enum.map(episodes, &serialize_episode/1),
      season: season_number
    })
  end

  # ============================================
  # SERIALIZATION
  # ============================================

  defp serialize_content(content) do
    %{
      id: content.id,
      type: content.type,
      title: content.title,
      slug: content.slug,
      poster_url: content.poster_url,
      backdrop_url: content.backdrop_url,
      release_year: content.release_year,
      maturity_rating: content.maturity_rating,
      genres: Enum.map(content.genres || [], & &1.name)
    }
  end

  defp serialize_content_detail(content) do
    %{
      id: content.id,
      type: content.type,
      title: content.title,
      original_title: content.original_title,
      slug: content.slug,
      description: content.description,
      tagline: content.tagline,
      poster_url: content.poster_url,
      backdrop_url: content.backdrop_url,
      trailer_url: content.trailer_url,
      release_year: content.release_year,
      release_date: content.release_date,
      runtime_minutes: content.runtime_minutes,
      maturity_rating: content.maturity_rating,
      average_rating: content.average_rating,
      total_ratings: content.total_ratings,
      genres: Enum.map(content.genres || [], & &1.name),
      seasons: if(content.type == "series", do: length(content.seasons || []), else: nil)
    }
  end

  defp serialize_season(season) do
    %{
      id: season.id,
      season_number: season.season_number,
      title: season.title,
      description: season.description,
      poster_url: season.poster_url,
      episode_count: season.episode_count
    }
  end

  defp serialize_episode(episode) do
    %{
      id: episode.id,
      episode_number: episode.episode_number,
      title: episode.title,
      description: episode.description,
      runtime_minutes: episode.runtime_minutes,
      thumbnail_url: episode.thumbnail_url
    }
  end
end
