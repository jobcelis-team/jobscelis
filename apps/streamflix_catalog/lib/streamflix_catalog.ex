defmodule StreamflixCatalog do
  @moduledoc """
  StreamflixCatalog - Content catalog management.

  This module provides:
  - Movie and series management
  - Genre categorization
  - Content search and browsing
  - Video metadata management
  """

  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCatalog.Schemas.{Content, Genre, Season, Episode, Video}
  alias StreamflixCore.Events
  alias StreamflixCore.Events.EventBus
  alias StreamflixCore.Cache

  # ============================================
  # CONTENT FUNCTIONS
  # ============================================

  @doc """
  Creates new content (movie or series).
  """
  def create_content(attrs) do
    changeset = Content.changeset(%Content{}, attrs)

    case Repo.insert(changeset) do
      {:ok, content} ->
        # Handle genres if provided
        if genres = attrs[:genre_ids] || attrs["genre_ids"] do
          set_content_genres(content.id, genres)
        end

        EventBus.publish(Events.new(Events.ContentAdded, %{
          content_id: content.id,
          type: content.type,
          title: content.title,
          description: content.description,
          genres: genres || [],
          release_year: content.release_year,
          rating: content.rating,
          maturity_level: content.maturity_level,
          added_by: attrs[:added_by]
        }))

        {:ok, content}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets content by ID.
  """
  def get_content(id) do
    # Try cache first
    case Cache.get_content(id) do
      nil ->
        content = Repo.get(Content, id) |> Repo.preload([:genres, :seasons])
        if content, do: Cache.cache_content(id, content)
        content
      cached ->
        cached
    end
  end

  @doc """
  Gets content by ID, raises if not found.
  """
  def get_content!(id) do
    case get_content(id) do
      nil -> raise Ecto.NoResultsError, queryable: Content
      content -> content
    end
  end

  @doc """
  Gets content by slug.
  """
  def get_content_by_slug(slug) do
    Repo.get_by(Content, slug: slug)
    |> Repo.preload([:genres, :seasons])
  end

  @doc """
  Updates content.
  """
  def update_content(%Content{} = content, attrs) do
    changeset = Content.changeset(content, attrs)

    case Repo.update(changeset) do
      {:ok, updated} ->
        Cache.invalidate_content(updated.id)
        {:ok, updated}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Publishes content (makes it available).
  """
  def publish_content(content_id, regions \\ ["global"]) do
    content = get_content!(content_id)

    case update_content(content, %{status: "published"}) do
      {:ok, content} ->
        EventBus.publish(Events.new(Events.ContentPublished, %{
          content_id: content.id,
          regions: regions
        }))

        {:ok, content}

      error ->
        error
    end
  end

  @doc """
  Deactivates content (soft delete).
  """
  def delete_content(%Content{} = content) do
    Cache.invalidate_content(content.id)
    changeset = Content.changeset(content, %{status: "archived"})
    
    case Repo.update(changeset) do
      {:ok, updated} -> {:ok, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Activates content.
  """
  def activate_content(%Content{} = content) do
    Cache.invalidate_content(content.id)
    changeset = Content.changeset(content, %{status: "published"})
    
    case Repo.update(changeset) do
      {:ok, updated} -> {:ok, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  # ============================================
  # BROWSING FUNCTIONS
  # ============================================

  @doc """
  Lists all published content with pagination.
  """
  def list_content(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)
    type = Keyword.get(opts, :type)
    include_archived = Keyword.get(opts, :include_archived, false)
    include_all = Keyword.get(opts, :include_all, false)  # For admin: show all statuses

    query = cond do
      include_all ->
        # Admin view: show all statuses (draft, published, archived)
        Content
        |> order_by([c], desc: c.view_count)
      include_archived ->
        # Show published and archived
        Content
        |> where([c], c.status == "published" or c.status == "archived")
        |> order_by([c], desc: c.view_count)
      true ->
        # Default: only published
        Content
        |> where([c], c.status == "published")
        |> order_by([c], desc: c.view_count)
    end

    query = if type, do: where(query, [c], c.type == ^type), else: query

    query
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
    |> Repo.all()
    |> Repo.preload(:genres)
  end

  @doc """
  Lists content by genre.
  """
  def list_by_genre(genre_slug, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)

    from(c in Content,
      join: cg in "content_genres", on: cg.content_id == c.id,
      join: g in Genre, on: g.id == cg.genre_id,
      where: g.slug == ^genre_slug and c.status == "published",
      order_by: [desc: c.view_count],
      limit: ^per_page,
      offset: ^((page - 1) * per_page),
      preload: [:genres]
    )
    |> Repo.all()
  end

  @doc """
  Gets trending content.
  """
  def get_trending(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    Content
    |> where([c], c.status == "published")
    |> order_by([c], desc: c.view_count)
    |> limit(^limit)
    |> Repo.all()
    |> Repo.preload(:genres)
  end

  @doc """
  Gets new releases.
  """
  def get_new_releases(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    days = Keyword.get(opts, :days, 30)
    cutoff = Date.add(Date.utc_today(), -days)

    Content
    |> where([c], c.status == "published")
    |> where([c], c.release_date >= ^cutoff)
    |> order_by([c], desc: c.release_date)
    |> limit(^limit)
    |> Repo.all()
    |> Repo.preload(:genres)
  end

  @doc """
  Gets top rated content.
  """
  def get_top_rated(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_ratings = Keyword.get(opts, :min_ratings, 10)

    Content
    |> where([c], c.status == "published")
    |> where([c], c.total_ratings >= ^min_ratings)
    |> order_by([c], desc: c.average_rating)
    |> limit(^limit)
    |> Repo.all()
    |> Repo.preload(:genres)
  end

  @doc """
  Searches content by title.
  """
  def search(query_string, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    search_term = "%#{query_string}%"

    from(c in Content,
      where: c.status == "published",
      where: ilike(c.title, ^search_term) or ilike(c.description, ^search_term),
      order_by: [desc: c.view_count],
      limit: ^limit,
      preload: [:genres]
    )
    |> Repo.all()
  end

  # ============================================
  # GENRE FUNCTIONS
  # ============================================

  @doc """
  Lists all genres.
  """
  def list_genres do
    Genre
    |> order_by([g], asc: g.name)
    |> Repo.all()
  end

  @doc """
  Gets a genre by slug.
  """
  def get_genre_by_slug(slug) do
    Repo.get_by(Genre, slug: slug)
  end

  @doc """
  Sets genres for content.
  """
  def set_content_genres(content_id, genre_ids) do
    # Remove existing
    Repo.delete_all(from cg in "content_genres", where: cg.content_id == ^content_id)

    # Add new
    entries = Enum.map(genre_ids, fn genre_id ->
      %{content_id: content_id, genre_id: genre_id}
    end)

    Repo.insert_all("content_genres", entries)
  end

  # ============================================
  # SEASON & EPISODE FUNCTIONS
  # ============================================

  @doc """
  Adds a season to a series.
  """
  def add_season(content_id, attrs) do
    changeset = Season.changeset(%Season{content_id: content_id}, attrs)

    case Repo.insert(changeset) do
      {:ok, season} ->
        EventBus.publish(Events.new(Events.SeasonAdded, %{
          season_id: season.id,
          content_id: content_id,
          season_number: season.season_number,
          title: season.title
        }))

        {:ok, season}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets seasons for a series.
  """
  def get_seasons(content_id) do
    Season
    |> where([s], s.content_id == ^content_id)
    |> order_by([s], asc: s.season_number)
    |> Repo.all()
  end

  @doc """
  Adds an episode to a season.
  """
  def add_episode(season_id, attrs) do
    season = Repo.get!(Season, season_id)
    changeset = Episode.changeset(%Episode{season_id: season_id}, attrs)

    case Repo.insert(changeset) do
      {:ok, episode} ->
        EventBus.publish(Events.new(Events.EpisodeAdded, %{
          episode_id: episode.id,
          season_id: season_id,
          content_id: season.content_id,
          episode_number: episode.episode_number,
          title: episode.title,
          description: episode.description,
          duration_minutes: episode.duration_minutes
        }))

        {:ok, episode}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets a season by ID.
  """
  def get_season(id) do
    Repo.get(Season, id) |> Repo.preload(:episodes)
  end

  @doc """
  Updates a season.
  """
  def update_season(%Season{} = season, attrs) do
    changeset = Season.changeset(season, attrs)
    
    case Repo.update(changeset) do
      {:ok, updated} -> {:ok, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Deletes a season (soft delete by marking as inactive if needed, or hard delete).
  """
  def delete_season(%Season{} = season) do
    Repo.delete(season)
  end

  @doc """
  Gets episodes for a season.
  """
  def get_episodes(season_id) do
    Episode
    |> where([e], e.season_id == ^season_id)
    |> order_by([e], asc: e.episode_number)
    |> Repo.all()
  end

  @doc """
  Gets an episode by ID.
  """
  def get_episode(id) do
    Repo.get(Episode, id) |> Repo.preload(:season)
  end

  @doc """
  Gets episode by content + season number + episode number.
  Returns nil if not found (e.g. movie).
  """
  def get_episode_by_position(content_id, season_number, episode_number) do
    season =
      Season
      |> where([s], s.content_id == ^content_id and s.season_number == ^season_number)
      |> Repo.one()

    if season do
      Episode
      |> where([e], e.season_id == ^season.id and e.episode_number == ^episode_number)
      |> Repo.one()
      |> case do
        nil -> nil
        ep -> Repo.preload(ep, :season)
      end
    else
      nil
    end
  end

  @doc """
  Updates an episode.
  """
  def update_episode(%Episode{} = episode, attrs) do
    changeset = Episode.changeset(episode, attrs)
    
    case Repo.update(changeset) do
      {:ok, updated} -> {:ok, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Deletes an episode.
  """
  def delete_episode(%Episode{} = episode) do
    Repo.delete(episode)
  end

  @doc """
  Gets the next episode after the current one.
  """
  def get_next_episode(content_id, current_season, current_episode) do
    # Try next episode in same season
    next_in_season =
      from(e in Episode,
        join: s in Season, on: s.id == e.season_id,
        where: s.content_id == ^content_id,
        where: s.season_number == ^current_season,
        where: e.episode_number == ^(current_episode + 1)
      )
      |> Repo.one()

    if next_in_season do
      next_in_season
    else
      # Try first episode of next season
      from(e in Episode,
        join: s in Season, on: s.id == e.season_id,
        where: s.content_id == ^content_id,
        where: s.season_number == ^(current_season + 1),
        where: e.episode_number == 1
      )
      |> Repo.one()
    end
  end

  # ============================================
  # VIDEO FUNCTIONS
  # ============================================

  @doc """
  Gets video for content (movie).
  """
  def get_video_for_content(content_id) do
    Video
    |> where([v], v.content_id == ^content_id)
    |> where([v], v.status == "ready")
    |> Repo.one()
    |> Repo.preload(:qualities)
  end

  @doc """
  Gets video for episode.
  """
  def get_video_for_episode(episode_id) do
    Video
    |> where([v], v.episode_id == ^episode_id)
    |> where([v], v.status == "ready")
    |> Repo.one()
    |> Repo.preload(:qualities)
  end

  @doc """
  Increments view count for content.
  """
  def increment_views(content_id) do
    from(c in Content, where: c.id == ^content_id)
    |> Repo.update_all(inc: [view_count: 1])

    # Update cache
    Cache.invalidate_content(content_id)
  end

  # ============================================
  # AUTOCOMPLETE FUNCTIONS
  # ============================================

  @doc """
  Returns autocomplete suggestions for search.
  """
  def autocomplete(query_string, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    search_term = "#{query_string}%"

    from(c in Content,
      where: c.status == "published",
      where: ilike(c.title, ^search_term),
      order_by: [desc: c.view_count],
      limit: ^limit,
      select: c.title
    )
    |> Repo.all()
  end

  # ============================================
  # MY LIST FUNCTIONS
  # ============================================

  alias StreamflixCatalog.Schemas.MyList

  @doc """
  Gets user's my list by profile_id.
  """
  def get_my_list(profile_id) do
    MyList
    |> where([ml], ml.profile_id == ^profile_id)
    |> order_by([ml], desc: ml.added_at)
    |> preload(:content)
    |> Repo.all()
    |> Enum.map(fn item ->
      if item.content do
        Map.put(item.content, :added_at, item.added_at)
      else
        nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  @doc """
  Checks if content is in user's my list.
  """
  def in_my_list?(profile_id, content_id) do
    MyList
    |> where([ml], ml.profile_id == ^profile_id and ml.content_id == ^content_id)
    |> Repo.exists?()
  end

  @doc """
  Adds content to my list.
  """
  def add_to_my_list(profile_id, content_id) do
    attrs = %{
      profile_id: profile_id,
      content_id: content_id,
      added_at: DateTime.utc_now()
    }

    changeset = MyList.changeset(%MyList{}, attrs)

    case Repo.insert(changeset) do
      {:ok, _my_list} -> {:ok, :added}
      {:error, %Ecto.Changeset{errors: errors}} ->
        if Keyword.has_key?(errors, :profile_id) or Keyword.has_key?(errors, :content_id) do
          {:error, :already_in_list}
        else
          {:error, :insert_failed}
        end
    end
  end

  @doc """
  Removes content from my list.
  """
  def remove_from_my_list(profile_id, content_id) do
    case Repo.get_by(MyList, profile_id: profile_id, content_id: content_id) do
      nil -> {:error, :not_in_list}
      my_list ->
        case Repo.delete(my_list) do
          {:ok, _} -> {:ok, :removed}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  # ============================================
  # RATING FUNCTIONS
  # ============================================

  @doc """
  Rates content.
  """
  def rate_content(user_id, profile_id, content_id, rating) do
    now = DateTime.utc_now()

    # Upsert rating
    entry = %{
      user_id: user_id,
      profile_id: profile_id,
      content_id: content_id,
      rating: rating,
      rated_at: now
    }

    # Try to delete existing first
    from(r in "content_ratings",
      where: r.user_id == ^user_id and r.content_id == ^content_id
    ) |> Repo.delete_all()

    case Repo.insert_all("content_ratings", [entry]) do
      {1, _} ->
        # Update content average rating
        update_content_rating(content_id)
        {:ok, :rated}

      _ ->
        {:error, :rating_failed}
    end
  end

  @doc """
  Removes a rating from content.
  """
  def remove_rating(user_id, profile_id, content_id) do
    query = from(r in "content_ratings",
      where: r.user_id == ^user_id and r.content_id == ^content_id
    )

    query = if profile_id do
      from(r in query, where: r.profile_id == ^profile_id)
    else
      query
    end

    case Repo.delete_all(query) do
      {0, _} -> {:ok, :not_rated}
      {_, _} ->
        update_content_rating(content_id)
        {:ok, :removed}
    end
  end

  defp update_content_rating(content_id) do
    result = from(r in "content_ratings",
      where: r.content_id == ^content_id,
      select: %{avg: avg(r.rating), count: count(r.id)}
    ) |> Repo.one()

    if result do
      from(c in Content, where: c.id == ^content_id)
      |> Repo.update_all(set: [
        average_rating: result.avg || 0,
        total_ratings: result.count || 0
      ])

      Cache.invalidate_content(content_id)
    end
  end

  # ============================================
  # WATCH HISTORY FUNCTIONS
  # ============================================

  alias StreamflixCatalog.Schemas.WatchHistory

  @doc """
  Updates or creates watch history entry.
  """
  def update_watch_history(profile_id, attrs) do
    content_id = attrs[:content_id]
    episode_id = attrs[:episode_id]
    video_id = attrs[:video_id]
    progress_seconds = attrs[:progress_seconds] || 0
    duration_seconds = attrs[:duration_seconds]

    # Find existing entry (use is_nil/1 for nil - Ecto forbids == ^nil)
    base = WatchHistory
      |> where([wh], wh.profile_id == ^profile_id)
      |> where([wh], wh.content_id == ^content_id)

    existing = if is_nil(episode_id) do
      base |> where([wh], is_nil(wh.episode_id)) |> Repo.one()
    else
      base |> where([wh], wh.episode_id == ^episode_id) |> Repo.one()
    end

    history_attrs = %{
      profile_id: profile_id,
      content_id: content_id,
      episode_id: episode_id,
      video_id: video_id,
      progress_seconds: progress_seconds,
      duration_seconds: duration_seconds,
      last_watched_at: DateTime.utc_now(),
      completed: if(duration_seconds && progress_seconds >= duration_seconds * 0.9, do: true, else: false)
    }

    if existing do
      changeset = WatchHistory.changeset(existing, history_attrs)
      Repo.update(changeset)
    else
      changeset = WatchHistory.changeset(%WatchHistory{}, history_attrs)
      Repo.insert(changeset)
    end
  end

  @doc """
  Gets watch history for a profile.
  """
  def get_watch_history(profile_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    WatchHistory
    |> where([wh], wh.profile_id == ^profile_id)
    |> order_by([wh], desc: wh.last_watched_at)
    |> limit(^limit)
    |> preload(:content)
    |> Repo.all()
  end

  @doc """
  Gets continue watching (incomplete items) for a profile.
  """
  def get_continue_watching(profile_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    WatchHistory
    |> where([wh], wh.profile_id == ^profile_id)
    |> where([wh], wh.completed == false)
    |> order_by([wh], desc: wh.last_watched_at)
    |> limit(^limit)
    |> preload([:content, :episode])
    |> Repo.all()
  end

  @doc """
  Gets watch progress for specific content/episode.
  """
  def get_watch_progress(profile_id, content_id, episode_id \\ nil) do
    query = 
      WatchHistory
      |> where([wh], wh.profile_id == ^profile_id)
      |> where([wh], wh.content_id == ^content_id)

    query = if episode_id do
      where(query, [wh], wh.episode_id == ^episode_id)
    else
      where(query, [wh], is_nil(wh.episode_id))
    end

    Repo.one(query)
  end
end
