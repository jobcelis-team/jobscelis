defmodule StreamflixCore.Schemas.Notification do
  @moduledoc """
  Internal notification for users. Types: webhook_failing, job_failed, dlq_entry, etc.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notifications" do
    field :type, :string
    field :title, :string
    field :message, :string
    field :metadata, :map, default: %{}
    field :read, :boolean, default: false
    field :read_at, :utc_datetime_usec

    field :user_id, :binary_id
    belongs_to :project, StreamflixCore.Schemas.Project

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :project_id, :type, :title, :message, :metadata, :read, :read_at])
    |> validate_required([:user_id, :type, :title])
    |> foreign_key_constraint(:user_id)
  end
end
