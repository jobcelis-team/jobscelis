defmodule StreamflixCatalog.Schemas.Season do
  @moduledoc """
  Season schema for TV series.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "seasons" do
    field :season_number, :integer
    field :title, :string
    field :description, :string
    field :poster_url, :string
    field :release_date, :date

    belongs_to :content, StreamflixCatalog.Schemas.Content
    has_many :episodes, StreamflixCatalog.Schemas.Episode

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields [:season_number, :content_id]
  @optional_fields [:title, :description, :poster_url, :release_date]

  def changeset(season, attrs) do
    season
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:season_number, greater_than: 0)
    |> unique_constraint([:content_id, :season_number])
    |> foreign_key_constraint(:content_id)
  end
end
