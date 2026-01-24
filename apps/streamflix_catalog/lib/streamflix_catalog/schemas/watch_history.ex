defmodule StreamflixCatalog.Schemas.WatchHistory do
  @moduledoc """
  WatchHistory schema - Tracks user viewing progress.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "watch_history" do
    field :progress_seconds, :integer, default: 0
    field :duration_seconds, :integer
    field :progress_percent, :decimal, default: 0.0
    field :completed, :boolean, default: false
    field :last_watched_at, :utc_datetime_usec

    field :profile_id, :binary_id
    field :content_id, :binary_id
    field :episode_id, :binary_id
    field :video_id, :binary_id

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields [:profile_id, :last_watched_at]
  @optional_fields [:content_id, :episode_id, :video_id, :progress_seconds, :duration_seconds, :progress_percent, :completed]

  def changeset(watch_history, attrs) do
    watch_history
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:progress_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:progress_percent, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> calculate_progress_percent()
    |> foreign_key_constraint(:profile_id)
    |> foreign_key_constraint(:content_id)
    |> foreign_key_constraint(:episode_id)
    |> foreign_key_constraint(:video_id)
  end

  defp calculate_progress_percent(changeset) do
    progress = get_change(changeset, :progress_seconds) || get_field(changeset, :progress_seconds) || 0
    duration = get_change(changeset, :duration_seconds) || get_field(changeset, :duration_seconds)

    if duration && duration > 0 do
      percent = Decimal.div(Decimal.new(progress), Decimal.new(duration)) |> Decimal.mult(Decimal.new(100))
      put_change(changeset, :progress_percent, percent)
    else
      changeset
    end
  end
end
