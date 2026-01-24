defmodule StreamflixCatalog.Schemas.Content do
  @moduledoc """
  Content schema for movies and series.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "content" do
    field :type, :string  # movie, series
    field :title, :string
    field :slug, :string
    field :description, :string
    field :synopsis, :string
    field :release_year, :integer
    field :release_date, :date
    field :duration_minutes, :integer
    field :status, :string, default: "draft"
    field :rating, :string  # PG, PG-13, R, etc.
    field :maturity_level, :string, default: "adult"
    field :poster_url, :string
    field :backdrop_url, :string
    field :trailer_url, :string
    field :imdb_id, :string
    field :tmdb_id, :integer
    field :average_rating, :decimal, default: 0.0
    field :total_ratings, :integer, default: 0
    field :view_count, :integer, default: 0
    field :featured, :boolean, default: false
    field :metadata, :map, default: %{}

    many_to_many :genres, StreamflixCatalog.Schemas.Genre,
      join_through: "content_genres",
      on_replace: :delete

    has_many :seasons, StreamflixCatalog.Schemas.Season, foreign_key: :content_id
    has_one :video, StreamflixCatalog.Schemas.Video

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields [:type, :title]
  @optional_fields [
    :slug, :description, :synopsis, :release_year,
    :release_date, :duration_minutes, :status, :rating, :maturity_level,
    :poster_url, :backdrop_url, :trailer_url, :imdb_id, :tmdb_id,
    :average_rating, :total_ratings, :view_count, :featured, :metadata
  ]

  def changeset(content, attrs) do
    content
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:type, ["movie", "series"])
    |> validate_inclusion(:status, ["draft", "published", "archived"])
    |> validate_inclusion(:rating, ["G", "PG", "PG-13", "R", "NC-17", "TV-MA", nil])
    |> generate_slug()
    |> unique_constraint(:slug)
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        case get_change(changeset, :title) do
          nil -> changeset
          title ->
            slug = slugify(title)
            put_change(changeset, :slug, slug)
        end
      _ ->
        changeset
    end
  end

  defp slugify(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.normalize(:nfd)
    |> String.replace(~r/[^a-z0-9\s-]/u, "")
    |> String.replace(~r/[\s-]+/, "-")
    |> String.trim("-")
  end

  defp slugify(_), do: nil

  # ============================================
  # QUERY HELPERS
  # ============================================

  def movies(query \\ __MODULE__) do
    from c in query, where: c.type == "movie"
  end

  def series(query \\ __MODULE__) do
    from c in query, where: c.type == "series"
  end

  def published(query \\ __MODULE__) do
    from c in query, where: c.status == "published"
  end

  def by_genre(query \\ __MODULE__, genre_id) do
    from c in query,
      join: cg in "content_genres", on: cg.content_id == c.id,
      where: cg.genre_id == ^genre_id
  end
end
