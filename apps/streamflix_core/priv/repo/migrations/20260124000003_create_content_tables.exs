defmodule StreamflixCore.Repo.Migrations.CreateContentTables do
  use Ecto.Migration

  def change do
    # ============================================
    # GENRES TABLE
    # ============================================
    create_if_not_exists table(:genres, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:genres, [:slug])

    # ============================================
    # CONTENT TABLE (Movies & Series)
    # ============================================
    create_if_not_exists table(:content, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :title, :string, null: false
      add :slug, :string, null: false
      add :type, :string, null: false  # movie, series
      add :description, :text
      add :synopsis, :text
      add :release_year, :integer
      add :release_date, :date
      add :duration_minutes, :integer  # For movies
      add :rating, :string  # PG, PG-13, R, etc.
      add :maturity_level, :string, default: "adult"
      add :status, :string, default: "draft"  # draft, published, archived
      add :poster_url, :string
      add :backdrop_url, :string
      add :trailer_url, :string
      add :imdb_id, :string
      add :tmdb_id, :integer
      add :average_rating, :decimal, precision: 3, scale: 2, default: 0.0
      add :total_ratings, :integer, default: 0
      add :view_count, :bigint, default: 0
      add :featured, :boolean, default: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:content, [:slug])
    create_if_not_exists index(:content, [:type])
    create_if_not_exists index(:content, [:status])
    create_if_not_exists index(:content, [:release_year])
    create_if_not_exists index(:content, [:featured])
    create_if_not_exists index(:content, [:view_count])
    create_if_not_exists index(:content, [:average_rating])

    # ============================================
    # CONTENT_GENRES JOIN TABLE
    # ============================================
    create_if_not_exists table(:content_genres, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :content_id, references(:content, type: :binary_id, on_delete: :delete_all), null: false
      add :genre_id, references(:genres, type: :binary_id, on_delete: :delete_all), null: false
    end

    create_if_not_exists unique_index(:content_genres, [:content_id, :genre_id])
    create_if_not_exists index(:content_genres, [:genre_id])

    # ============================================
    # SEASONS TABLE (For Series)
    # ============================================
    create_if_not_exists table(:seasons, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :content_id, references(:content, type: :binary_id, on_delete: :delete_all), null: false
      add :season_number, :integer, null: false
      add :title, :string
      add :description, :text
      add :release_date, :date
      add :poster_url, :string

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:seasons, [:content_id, :season_number])

    # ============================================
    # EPISODES TABLE
    # ============================================
    create_if_not_exists table(:episodes, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :season_id, references(:seasons, type: :binary_id, on_delete: :delete_all), null: false
      add :episode_number, :integer, null: false
      add :title, :string, null: false
      add :description, :text
      add :duration_minutes, :integer
      add :release_date, :date
      add :thumbnail_url, :string

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:episodes, [:season_id, :episode_number])

    # ============================================
    # CONTENT_AVAILABILITY TABLE (Regional availability)
    # ============================================
    create_if_not_exists table(:content_availability, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :content_id, references(:content, type: :binary_id, on_delete: :delete_all), null: false
      add :region, :string, null: false  # ISO country codes
      add :available_from, :utc_datetime_usec
      add :available_until, :utc_datetime_usec
      add :license_type, :string

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:content_availability, [:content_id, :region])

    # ============================================
    # PEOPLE TABLE (Actors, Directors, etc.)
    # ============================================
    create_if_not_exists table(:people, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, null: false
      add :slug, :string, null: false
      add :photo_url, :string
      add :bio, :text
      add :birth_date, :date
      add :imdb_id, :string
      add :tmdb_id, :integer

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:people, [:slug])

    # ============================================
    # CONTENT_CAST TABLE
    # ============================================
    create_if_not_exists table(:content_cast, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :content_id, references(:content, type: :binary_id, on_delete: :delete_all), null: false
      add :person_id, references(:people, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, null: false  # actor, director, writer, producer
      add :character_name, :string
      add :order, :integer, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:content_cast, [:content_id])
    create_if_not_exists index(:content_cast, [:person_id])
  end
end
