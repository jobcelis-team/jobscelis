defmodule StreamflixCore.Repo.Migrations.AddSubscriptionColumns do
  use Ecto.Migration

  def change do
    alter table(:subscriptions) do
      add_if_not_exists :billing_cycle, :string, default: "monthly"
      add_if_not_exists :cancel_at_period_end, :boolean, default: false
    end
  end
end
