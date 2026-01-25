defmodule StreamflixCatalog.Schemas.Video do
  @moduledoc """
  Video schema for storing video file metadata.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "videos" do
    field :status, :string, default: "pending"
    field :original_filename, :string
    field :original_url, :string
    field :duration_seconds, :integer
    field :file_size_bytes, :integer
    field :codec, :string
    field :container, :string
    field :audio_channels, :integer
    field :metadata, :map, default: %{}

    belongs_to :content, StreamflixCatalog.Schemas.Content
    belongs_to :episode, StreamflixCatalog.Schemas.Episode
    has_many :quality_variants, StreamflixCatalog.Schemas.VideoQuality

    timestamps()
  end

  @required_fields []
  @optional_fields [
    :content_id, :episode_id, :status, :original_filename, :original_url,
    :duration_seconds, :file_size_bytes, :codec, :container, :audio_channels, :metadata
  ]

  def changeset(video, attrs) do
    video
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_inclusion(:status, ["pending", "processing", "ready", "failed"])
    |> validate_content_or_episode()
  end

  defp validate_content_or_episode(changeset) do
    content_id = get_field(changeset, :content_id)
    episode_id = get_field(changeset, :episode_id)

    cond do
      is_nil(content_id) and is_nil(episode_id) ->
        add_error(changeset, :content_id, "either content_id or episode_id must be set")

      not is_nil(content_id) and not is_nil(episode_id) ->
        add_error(changeset, :content_id, "cannot set both content_id and episode_id")

      true ->
        changeset
    end
  end
end
