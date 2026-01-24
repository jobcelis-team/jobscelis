defmodule StreamflixCore.Repo.Migrations.CreateUserActivityTables do
  use Ecto.Migration

  def change do
    # ============================================
    # WATCH_HISTORY TABLE
    # ============================================
    create_if_not_exists table(:watch_history, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all), null: false
      add :content_id, references(:content, type: :binary_id, on_delete: :delete_all)
      add :episode_id, references(:episodes, type: :binary_id, on_delete: :delete_all)
      add :video_id, references(:videos, type: :binary_id, on_delete: :delete_all)
      add :progress_seconds, :integer, default: 0
      add :duration_seconds, :integer
      add :progress_percent, :decimal, precision: 5, scale: 2, default: 0.0
      add :completed, :boolean, default: false
      add :last_watched_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:watch_history, [:profile_id])
    create_if_not_exists index(:watch_history, [:content_id])
    create_if_not_exists index(:watch_history, [:episode_id])
    create_if_not_exists index(:watch_history, [:last_watched_at])
    create_if_not_exists unique_index(:watch_history, [:profile_id, :content_id], 
      where: "episode_id IS NULL", name: :watch_history_profile_content_unique)
    create_if_not_exists unique_index(:watch_history, [:profile_id, :episode_id], 
      where: "episode_id IS NOT NULL", name: :watch_history_profile_episode_unique)

    # ============================================
    # MY_LIST TABLE (User's watchlist)
    # ============================================
    create_if_not_exists table(:my_list, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all), null: false
      add :content_id, references(:content, type: :binary_id, on_delete: :delete_all), null: false
      add :added_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:my_list, [:profile_id, :content_id])
    create_if_not_exists index(:my_list, [:added_at])

    # ============================================
    # RATINGS TABLE
    # ============================================
    create_if_not_exists table(:ratings, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all), null: false
      add :content_id, references(:content, type: :binary_id, on_delete: :delete_all), null: false
      add :rating, :integer, null: false  # 1-5 stars or thumbs up/down (1 or 5)
      add :rating_type, :string, default: "stars"  # stars, thumbs

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:ratings, [:profile_id, :content_id])
    create_if_not_exists index(:ratings, [:content_id])

    # ============================================
    # PLAYBACK_SESSIONS TABLE (Active streaming sessions)
    # ============================================
    create_if_not_exists table(:playback_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all), null: false
      add :video_id, references(:videos, type: :binary_id, on_delete: :delete_all), null: false
      add :device_id, :string
      add :device_type, :string
      add :device_name, :string
      add :ip_address, :string
      add :user_agent, :string
      add :quality, :string
      add :position_seconds, :integer, default: 0
      add :bandwidth_kbps, :integer
      add :buffer_health, :decimal, precision: 5, scale: 2
      add :started_at, :utc_datetime_usec, null: false
      add :last_heartbeat_at, :utc_datetime_usec, null: false
      add :ended_at, :utc_datetime_usec
      add :status, :string, default: "active"  # active, paused, ended
      add :node_id, :string  # Which BEAM node is handling this session

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:playback_sessions, [:user_id])
    create_if_not_exists index(:playback_sessions, [:profile_id])
    create_if_not_exists index(:playback_sessions, [:video_id])
    create_if_not_exists index(:playback_sessions, [:status])
    create_if_not_exists index(:playback_sessions, [:last_heartbeat_at])
    create_if_not_exists index(:playback_sessions, [:node_id])
  end
end
