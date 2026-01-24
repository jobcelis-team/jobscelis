defmodule StreamflixCatalog.Schemas.Episode do
  @moduledoc """
  Episode schema for TV series.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "episodes" do
    field :episode_number, :integer
    field :title, :string
    field :description, :string
    field :duration_minutes, :integer
    field :thumbnail_url, :string
    field :release_date, :date

    belongs_to :season, StreamflixCatalog.Schemas.Season
    has_one :video, StreamflixCatalog.Schemas.Video

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields [:episode_number, :title, :season_id]
  @optional_fields [:description, :duration_minutes, :thumbnail_url, :release_date]

  def changeset(episode, attrs) do
    episode
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:episode_number, greater_than: 0)
    |> unique_constraint([:season_id, :episode_number])
    |> foreign_key_constraint(:season_id)
  end
end
