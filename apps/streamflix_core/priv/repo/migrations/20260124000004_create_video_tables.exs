defmodule StreamflixCore.Repo.Migrations.CreateVideoTables do
  use Ecto.Migration

  def change do
    # ============================================
    # VIDEOS TABLE
    # ============================================
    create_if_not_exists table(:videos, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :content_id, references(:content, type: :binary_id, on_delete: :delete_all)
      add :episode_id, references(:episodes, type: :binary_id, on_delete: :delete_all)
      add :status, :string, null: false, default: "pending"  # pending, processing, ready, failed
      add :original_filename, :string
      add :original_url, :string
      add :duration_seconds, :integer
      add :file_size_bytes, :bigint
      add :codec, :string
      add :container, :string
      add :audio_channels, :integer
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:videos, [:content_id])
    create_if_not_exists index(:videos, [:episode_id])
    create_if_not_exists index(:videos, [:status])

    # Ensure video belongs to either content OR episode
    execute """
    DO $$ BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'videos_content_or_episode_check') THEN
        ALTER TABLE videos ADD CONSTRAINT videos_content_or_episode_check
        CHECK (
          (content_id IS NOT NULL AND episode_id IS NULL) OR
          (content_id IS NULL AND episode_id IS NOT NULL)
        );
      END IF;
    END $$;
    """, """
    ALTER TABLE videos DROP CONSTRAINT IF EXISTS videos_content_or_episode_check;
    """

    # ============================================
    # VIDEO_QUALITIES TABLE (Multiple quality variants)
    # ============================================
    create_if_not_exists table(:video_qualities, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :video_id, references(:videos, type: :binary_id, on_delete: :delete_all), null: false
      add :quality, :string, null: false  # 360p, 480p, 720p, 1080p, 4k
      add :resolution_width, :integer
      add :resolution_height, :integer
      add :bitrate_kbps, :integer
      add :codec, :string
      add :manifest_url, :string
      add :segment_duration, :integer, default: 6
      add :file_size_bytes, :bigint
      add :status, :string, default: "pending"

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:video_qualities, [:video_id, :quality])
    create_if_not_exists index(:video_qualities, [:status])

    # ============================================
    # TRANSCODING_JOBS TABLE
    # ============================================
    create_if_not_exists table(:transcoding_jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :video_id, references(:videos, type: :binary_id, on_delete: :delete_all), null: false
      add :video_quality_id, references(:video_qualities, type: :binary_id, on_delete: :delete_all)
      add :status, :string, null: false, default: "queued"  # queued, processing, completed, failed
      add :progress_percent, :integer, default: 0
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :error_message, :text
      add :worker_node, :string
      add :priority, :integer, default: 0
      add :attempts, :integer, default: 0
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:transcoding_jobs, [:video_id])
    create_if_not_exists index(:transcoding_jobs, [:status])
    create_if_not_exists index(:transcoding_jobs, [:priority, :inserted_at])
  end
end
