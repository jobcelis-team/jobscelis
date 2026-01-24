defmodule StreamflixCore.Repo.Migrations.CreateUsersTables do
  use Ecto.Migration

  def change do
    # ============================================
    # USERS TABLE
    # ============================================
    create_if_not_exists table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :email, :citext, null: false
      add :password_hash, :string, null: false
      add :name, :string, null: false
      add :status, :string, null: false, default: "active"
      add :email_verified_at, :utc_datetime_usec
      add :last_login_at, :utc_datetime_usec
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:users, [:email])
    create_if_not_exists index(:users, [:status])

    # ============================================
    # PROFILES TABLE (Multiple profiles per user - Netflix style)
    # ============================================
    create_if_not_exists table(:profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :avatar_url, :string
      add :is_kids, :boolean, default: false
      add :language, :string, default: "es"
      add :maturity_level, :string, default: "adult"
      add :preferences, :map, default: %{}
      add :pin_hash, :string

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:profiles, [:user_id])

    # ============================================
    # SUBSCRIPTIONS TABLE
    # ============================================
    create_if_not_exists table(:subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :plan, :string, null: false, default: "basic"
      add :status, :string, null: false, default: "active"
      add :current_period_start, :utc_datetime_usec
      add :current_period_end, :utc_datetime_usec
      add :cancelled_at, :utc_datetime_usec
      add :stripe_customer_id, :string
      add :stripe_subscription_id, :string
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:subscriptions, [:user_id])
    create_if_not_exists index(:subscriptions, [:status])
    create_if_not_exists index(:subscriptions, [:stripe_customer_id])

    # ============================================
    # PAYMENTS TABLE
    # ============================================
    create_if_not_exists table(:payments, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :subscription_id, references(:subscriptions, type: :binary_id, on_delete: :nilify_all)
      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :currency, :string, default: "USD"
      add :status, :string, null: false
      add :payment_method, :string
      add :stripe_payment_intent_id, :string
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:payments, [:user_id])
    create_if_not_exists index(:payments, [:subscription_id])
    create_if_not_exists index(:payments, [:status])
  end
end
