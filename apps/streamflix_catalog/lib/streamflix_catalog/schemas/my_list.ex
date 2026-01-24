defmodule StreamflixCatalog.Schemas.MyList do
  @moduledoc """
  MyList schema - User's watchlist/favorites.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "my_list" do
    field :added_at, :utc_datetime_usec

    field :profile_id, :binary_id
    field :content_id, :binary_id

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields [:profile_id, :content_id]
  @optional_fields [:added_at]

  def changeset(my_list, attrs) do
    my_list
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:profile_id, :content_id])
    |> foreign_key_constraint(:profile_id)
    |> foreign_key_constraint(:content_id)
  end
end
