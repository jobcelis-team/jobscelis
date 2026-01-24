defmodule StreamflixAccounts do
  @moduledoc """
  StreamflixAccounts - User management and authentication.

  This module provides:
  - User registration and management
  - Profile management (multiple profiles per user)
  - Authentication (JWT via Guardian)
  - Session management
  - Subscription plan tracking
  """

  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixAccounts.Schemas.{User, Profile, Subscription}
  alias StreamflixAccounts.Services.{Authentication, SessionManager}
  alias StreamflixCore.Events
  alias StreamflixCore.Events.EventBus

  # ============================================
  # USER FUNCTIONS
  # ============================================

  @doc """
  Registers a new user.
  """
  def register_user(attrs) do
    changeset = User.registration_changeset(%User{}, attrs)

    case Repo.insert(changeset) do
      {:ok, user} ->
        # Emit event
        EventBus.publish(Events.new(Events.UserRegistered, %{
          user_id: user.id,
          email: user.email,
          name: user.name,
          plan: attrs[:plan] || :basic
        }))

        # Create default profile
        {:ok, _profile} = create_profile(user.id, %{
          name: user.name || "Profile 1",
          is_kids: false
        })

        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets a user by ID.
  """
  def get_user(id) do
    Repo.get(User, id)
  end

  @doc """
  Gets a user by ID, raises if not found.
  """
  def get_user!(id) do
    Repo.get!(User, id)
  end

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Authenticates a user with email and password.
  """
  def authenticate(email, password) do
    Authentication.authenticate(email, password)
  end

  @doc """
  Generates an authentication token for a user.
  """
  def generate_token(user) do
    Authentication.generate_token(user)
  end

  @doc """
  Verifies and decodes a token.
  """
  def verify_token(token) do
    Authentication.verify_token(token)
  end

  # ============================================
  # PROFILE FUNCTIONS
  # ============================================

  @doc """
  Creates a new profile for a user.
  """
  def create_profile(user_id, attrs) do
    user = get_user!(user_id)
    profile_count = count_profiles(user_id)
    max_profiles = max_profiles_for_plan(user)

    if profile_count >= max_profiles do
      {:error, :max_profiles_reached}
    else
      changeset = Profile.changeset(%Profile{user_id: user_id}, attrs)

      case Repo.insert(changeset) do
        {:ok, profile} ->
          EventBus.publish(Events.new(Events.ProfileCreated, %{
            profile_id: profile.id,
            user_id: user_id,
            name: profile.name,
            avatar_url: profile.avatar_url,
            is_kids: profile.is_kids
          }))

          {:ok, profile}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Gets a profile by ID.
  """
  def get_profile(id) do
    Repo.get(Profile, id)
  end

  @doc """
  Gets a profile by ID, raises if not found.
  """
  def get_profile!(id) do
    Repo.get!(Profile, id)
  end

  @doc """
  Lists all profiles for a user.
  """
  def list_profiles(user_id) do
    Profile
    |> where([p], p.user_id == ^user_id)
    |> order_by([p], asc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Updates a profile.
  """
  def update_profile(%Profile{} = profile, attrs) do
    profile
    |> Profile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a profile.
  """
  def delete_profile(%Profile{} = profile) do
    # Ensure user has at least one profile
    profile_count = count_profiles(profile.user_id)

    if profile_count <= 1 do
      {:error, :cannot_delete_last_profile}
    else
      EventBus.publish(Events.new(Events.ProfileDeleted, %{
        profile_id: profile.id
      }))

      Repo.delete(profile)
    end
  end

  @doc """
  Counts profiles for a user.
  """
  def count_profiles(user_id) do
    Profile
    |> where([p], p.user_id == ^user_id)
    |> Repo.aggregate(:count)
  end

  # ============================================
  # SUBSCRIPTION FUNCTIONS
  # ============================================

  @doc """
  Gets the active subscription for a user.
  """
  def get_active_subscription(user_id) do
    Subscription
    |> where([s], s.user_id == ^user_id)
    |> where([s], s.status == "active")
    |> Repo.one()
  end

  @doc """
  Creates a subscription for a user.
  """
  def create_subscription(user_id, attrs) do
    now = DateTime.utc_now()
    period_end = calculate_period_end(now, attrs[:billing_cycle] || :monthly)

    subscription_attrs = Map.merge(attrs, %{
      user_id: user_id,
      status: "active",
      current_period_start: now,
      current_period_end: period_end
    })

    changeset = Subscription.changeset(%Subscription{}, subscription_attrs)

    case Repo.insert(changeset) do
      {:ok, subscription} ->
        EventBus.publish(Events.new(Events.SubscriptionCreated, %{
          subscription_id: subscription.id,
          user_id: user_id,
          plan: subscription.plan,
          price_cents: plan_price(subscription.plan),
          currency: "USD",
          billing_cycle: subscription.billing_cycle,
          started_at: now
        }))

        {:ok, subscription}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # ============================================
  # SESSION MANAGEMENT
  # ============================================

  @doc """
  Checks if user can start a new stream.
  """
  def can_start_stream?(user_id) do
    SessionManager.can_start_stream?(user_id)
  end

  @doc """
  Gets active stream count for user.
  """
  def active_stream_count(user_id) do
    SessionManager.active_session_count(user_id)
  end

  # ============================================
  # WATCH HISTORY
  # ============================================

  @doc """
  Gets watch history for a profile.
  """
  def get_watch_history(profile_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    from(w in "watch_history",
      where: w.profile_id == ^profile_id,
      order_by: [desc: w.last_watched_at],
      limit: ^limit,
      select: %{
        content_id: w.content_id,
        episode_id: w.episode_id,
        position_seconds: w.position_seconds,
        progress: w.progress,
        completed: w.completed,
        last_watched_at: w.last_watched_at
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets watch progress for specific content.
  """
  def get_watch_progress(profile_id, content_id) do
    from(w in "watch_history",
      where: w.profile_id == ^profile_id and w.content_id == ^content_id,
      select: %{
        position: w.position_seconds,
        progress: w.progress,
        completed: w.completed
      }
    )
    |> Repo.one()
  end

  # ============================================
  # PRIVATE FUNCTIONS
  # ============================================

  defp max_profiles_for_plan(%User{} = user) do
    subscription = get_active_subscription(user.id)

    case subscription do
      nil -> 1
      %{plan: "basic"} -> 1
      %{plan: "standard"} -> 3
      %{plan: "premium"} -> 5
      _ -> 1
    end
  end

  defp calculate_period_end(start, :monthly) do
    DateTime.add(start, 30 * 24 * 60 * 60, :second)
  end

  defp calculate_period_end(start, :yearly) do
    DateTime.add(start, 365 * 24 * 60 * 60, :second)
  end

  defp plan_price("basic"), do: 999
  defp plan_price("standard"), do: 1599
  defp plan_price("premium"), do: 2199
  defp plan_price(_), do: 999
end
