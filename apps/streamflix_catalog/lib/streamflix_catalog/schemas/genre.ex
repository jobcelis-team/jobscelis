defmodule StreamflixCatalog.Schemas.Genre do
  @moduledoc """
  Genre schema for content categorization.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "genres" do
    field :name, :string
    field :slug, :string
    field :description, :string

    many_to_many :content, StreamflixCatalog.Schemas.Content,
      join_through: "content_genres"

    timestamps()
  end

  @required_fields [:name, :slug]
  @optional_fields [:description]

  def changeset(genre, attrs) do
    genre
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:slug)
  end
end
