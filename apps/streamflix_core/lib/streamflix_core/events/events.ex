defmodule StreamflixCore.Events do
  @moduledoc """
  Domain Events for the StreamFlix platform.

  Events are immutable facts that represent something that has happened
  in the system. They are the source of truth for event sourcing.
  """

  # ============================================
  # USER EVENTS
  # ============================================

  defmodule UserRegistered do
    @moduledoc "Event when a new user registers"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :user_id,
      :email,
      :name,
      :plan,
      :timestamp
    ]
  end

  defmodule UserUpdated do
    @moduledoc "Event when user profile is updated"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :user_id,
      :changes,
      :timestamp
    ]
  end

  defmodule UserDeactivated do
    @moduledoc "Event when user account is deactivated"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :user_id,
      :reason,
      :timestamp
    ]
  end

  # ============================================
  # PROFILE EVENTS
  # ============================================

  defmodule ProfileCreated do
    @moduledoc "Event when a new profile is created"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :profile_id,
      :user_id,
      :name,
      :avatar_url,
      :is_kids,
      :timestamp
    ]
  end

  defmodule ProfileUpdated do
    @moduledoc "Event when profile is updated"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :profile_id,
      :changes,
      :timestamp
    ]
  end

  defmodule ProfileDeleted do
    @moduledoc "Event when profile is deleted"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :profile_id,
      :timestamp
    ]
  end

  # ============================================
  # CONTENT EVENTS
  # ============================================

  defmodule ContentAdded do
    @moduledoc "Event when new content (movie/series) is added"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :content_id,
      :type,
      :title,
      :description,
      :genres,
      :release_year,
      :maturity_rating,
      :added_by,
      :timestamp
    ]
  end

  defmodule ContentUpdated do
    @moduledoc "Event when content metadata is updated"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :content_id,
      :changes,
      :timestamp
    ]
  end

  defmodule ContentPublished do
    @moduledoc "Event when content is published and available"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :content_id,
      :regions,
      :timestamp
    ]
  end

  defmodule ContentUnpublished do
    @moduledoc "Event when content is unpublished"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :content_id,
      :reason,
      :timestamp
    ]
  end

  defmodule SeasonAdded do
    @moduledoc "Event when a season is added to a series"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :season_id,
      :series_id,
      :season_number,
      :title,
      :timestamp
    ]
  end

  defmodule EpisodeAdded do
    @moduledoc "Event when an episode is added"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :episode_id,
      :season_id,
      :series_id,
      :episode_number,
      :title,
      :description,
      :runtime_minutes,
      :timestamp
    ]
  end

  # ============================================
  # VIDEO EVENTS
  # ============================================

  defmodule VideoUploaded do
    @moduledoc "Event when original video is uploaded"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :video_id,
      :content_id,
      :episode_id,
      :original_url,
      :file_size,
      :format,
      :timestamp
    ]
  end

  defmodule TranscodingStarted do
    @moduledoc "Event when video transcoding begins"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :job_id,
      :video_id,
      :target_qualities,
      :timestamp
    ]
  end

  defmodule TranscodingProgress do
    @moduledoc "Event for transcoding progress updates"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :job_id,
      :video_id,
      :progress,
      :current_stage,
      :timestamp
    ]
  end

  defmodule TranscodingCompleted do
    @moduledoc "Event when transcoding is complete"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :job_id,
      :video_id,
      :manifest_url,
      :qualities,
      :duration_seconds,
      :timestamp
    ]
  end

  defmodule TranscodingFailed do
    @moduledoc "Event when transcoding fails"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :job_id,
      :video_id,
      :error,
      :timestamp
    ]
  end

  # ============================================
  # PLAYBACK EVENTS
  # ============================================

  defmodule PlaybackStarted do
    @moduledoc "Event when video playback starts"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :session_id,
      :user_id,
      :profile_id,
      :content_id,
      :episode_id,
      :device_type,
      :quality,
      :position,
      :timestamp
    ]
  end

  defmodule PlaybackProgress do
    @moduledoc "Event for playback position updates"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :session_id,
      :position,
      :quality,
      :timestamp
    ]
  end

  defmodule PlaybackPaused do
    @moduledoc "Event when playback is paused"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :session_id,
      :position,
      :timestamp
    ]
  end

  defmodule PlaybackResumed do
    @moduledoc "Event when playback is resumed"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :session_id,
      :position,
      :timestamp
    ]
  end

  defmodule PlaybackEnded do
    @moduledoc "Event when playback ends (completed or stopped)"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :session_id,
      :final_position,
      :watch_duration,
      :completed,
      :timestamp
    ]
  end

  defmodule QualityChanged do
    @moduledoc "Event when video quality changes during playback"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :session_id,
      :from_quality,
      :to_quality,
      :reason,
      :timestamp
    ]
  end

  defmodule BufferingOccurred do
    @moduledoc "Event when buffering occurs"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :session_id,
      :duration_ms,
      :position,
      :timestamp
    ]
  end

  # ============================================
  # SUBSCRIPTION EVENTS
  # ============================================

  defmodule SubscriptionCreated do
    @moduledoc "Event when subscription is created"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :subscription_id,
      :user_id,
      :plan,
      :price_cents,
      :currency,
      :billing_cycle,
      :started_at,
      :timestamp
    ]
  end

  defmodule SubscriptionUpgraded do
    @moduledoc "Event when subscription is upgraded"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :subscription_id,
      :from_plan,
      :to_plan,
      :proration_amount,
      :timestamp
    ]
  end

  defmodule SubscriptionDowngraded do
    @moduledoc "Event when subscription is downgraded"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :subscription_id,
      :from_plan,
      :to_plan,
      :effective_date,
      :timestamp
    ]
  end

  defmodule SubscriptionCancelled do
    @moduledoc "Event when subscription is cancelled"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :subscription_id,
      :reason,
      :effective_date,
      :timestamp
    ]
  end

  defmodule SubscriptionRenewed do
    @moduledoc "Event when subscription is renewed"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :subscription_id,
      :new_period_start,
      :new_period_end,
      :timestamp
    ]
  end

  defmodule PaymentProcessed do
    @moduledoc "Event when payment is processed"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :payment_id,
      :subscription_id,
      :amount_cents,
      :currency,
      :status,
      :provider_ref,
      :timestamp
    ]
  end

  defmodule PaymentFailed do
    @moduledoc "Event when payment fails"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :payment_id,
      :subscription_id,
      :amount_cents,
      :reason,
      :retry_count,
      :timestamp
    ]
  end

  # ============================================
  # USER INTERACTION EVENTS
  # ============================================

  defmodule ContentRated do
    @moduledoc "Event when user rates content"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :profile_id,
      :content_id,
      :rating,
      :rating_type,
      :timestamp
    ]
  end

  defmodule ContentAddedToList do
    @moduledoc "Event when content is added to My List"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :profile_id,
      :content_id,
      :timestamp
    ]
  end

  defmodule ContentRemovedFromList do
    @moduledoc "Event when content is removed from My List"
    @derive Jason.Encoder
    defstruct [
      :event_id,
      :profile_id,
      :content_id,
      :timestamp
    ]
  end

  # ============================================
  # HELPER FUNCTIONS
  # ============================================

  @doc """
  Returns the event type as a string.
  """
  def event_type(%{__struct__: module}) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  @doc """
  Creates a new event with auto-generated ID and timestamp.
  """
  def new(module, attrs) when is_atom(module) do
    struct(module, Map.merge(attrs, %{
      event_id: UUID.uuid4(),
      timestamp: DateTime.utc_now()
    }))
  end
end
