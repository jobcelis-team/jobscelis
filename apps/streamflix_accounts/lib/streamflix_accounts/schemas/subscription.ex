defmodule StreamflixAccounts.Schemas.Subscription do
  @moduledoc """
  Subscription schema for StreamFlix billing.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "subscriptions" do
    field :plan, :string
    field :status, :string
    field :billing_cycle, :string
    field :current_period_start, :utc_datetime
    field :current_period_end, :utc_datetime
    field :cancel_at_period_end, :boolean, default: false
    field :stripe_subscription_id, :string
    field :stripe_customer_id, :string

    belongs_to :user, StreamflixAccounts.Schemas.User

    timestamps()
  end

  @required_fields [:user_id, :plan, :status, :billing_cycle, :current_period_start, :current_period_end]
  @optional_fields [:cancel_at_period_end, :stripe_subscription_id, :stripe_customer_id]

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:plan, ["basic", "standard", "premium"])
    |> validate_inclusion(:status, ["active", "cancelled", "past_due", "trialing"])
    |> validate_inclusion(:billing_cycle, ["monthly", "yearly"])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:stripe_subscription_id)
  end

  # ============================================
  # PLAN CONFIGURATION
  # ============================================

  @plans %{
    "basic" => %{
      name: "Basic",
      price_monthly: 999,
      price_yearly: 9999,
      max_profiles: 1,
      max_streams: 1,
      video_quality: "480p",
      hd: false,
      uhd: false,
      downloads: false
    },
    "standard" => %{
      name: "Standard",
      price_monthly: 1599,
      price_yearly: 15999,
      max_profiles: 3,
      max_streams: 2,
      video_quality: "1080p",
      hd: true,
      uhd: false,
      downloads: true
    },
    "premium" => %{
      name: "Premium",
      price_monthly: 2199,
      price_yearly: 21999,
      max_profiles: 5,
      max_streams: 4,
      video_quality: "4K+HDR",
      hd: true,
      uhd: true,
      downloads: true
    }
  }

  def plans, do: @plans

  def get_plan(plan_id), do: Map.get(@plans, plan_id)

  def max_streams(%__MODULE__{plan: plan}) do
    case get_plan(plan) do
      nil -> 1
      config -> config.max_streams
    end
  end

  def max_profiles(%__MODULE__{plan: plan}) do
    case get_plan(plan) do
      nil -> 1
      config -> config.max_profiles
    end
  end

  def supports_hd?(%__MODULE__{plan: plan}) do
    case get_plan(plan) do
      nil -> false
      config -> config.hd
    end
  end

  def supports_uhd?(%__MODULE__{plan: plan}) do
    case get_plan(plan) do
      nil -> false
      config -> config.uhd
    end
  end
end
