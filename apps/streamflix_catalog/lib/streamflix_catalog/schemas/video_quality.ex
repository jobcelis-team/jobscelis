defmodule StreamflixCatalog.Schemas.VideoQuality do
  @moduledoc """
  Video quality variant schema.
  Stores different quality versions of a video (480p, 720p, 1080p, 4K).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "video_qualities" do
    field :quality, :string
    field :bitrate_kbps, :integer
    field :width, :integer
    field :height, :integer
    field :url, :string
    field :file_size_bytes, :integer
    field :codec, :string

    belongs_to :video, StreamflixCatalog.Schemas.Video

    timestamps()
  end

  @required_fields [:video_id, :quality, :url]
  @optional_fields [:bitrate_kbps, :width, :height, :file_size_bytes, :codec]

  def changeset(quality, attrs) do
    quality
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:quality, ["240p", "360p", "480p", "720p", "1080p", "1440p", "4k"])
    |> unique_constraint([:video_id, :quality])
    |> foreign_key_constraint(:video_id)
  end

  # ============================================
  # QUALITY CONFIGURATIONS
  # ============================================

  @quality_presets %{
    "240p" => %{width: 426, height: 240, bitrate_kbps: 400},
    "360p" => %{width: 640, height: 360, bitrate_kbps: 800},
    "480p" => %{width: 854, height: 480, bitrate_kbps: 1200},
    "720p" => %{width: 1280, height: 720, bitrate_kbps: 2500},
    "1080p" => %{width: 1920, height: 1080, bitrate_kbps: 5000},
    "1440p" => %{width: 2560, height: 1440, bitrate_kbps: 8000},
    "4k" => %{width: 3840, height: 2160, bitrate_kbps: 15000}
  }

  def presets, do: @quality_presets
  def get_preset(quality), do: Map.get(@quality_presets, quality)
end
