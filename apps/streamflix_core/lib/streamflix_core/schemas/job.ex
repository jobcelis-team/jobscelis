defmodule StreamflixCore.Schemas.Job do
  @moduledoc """
  Job schema: scheduled task (daily/weekly/monthly/cron).
  Action: emit_event or post_url. Only active jobs run.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "jobs" do
    field(:name, :string)
    field(:schedule_type, :string)
    field(:schedule_config, :map, default: %{})
    field(:action_type, :string)
    field(:action_config, :map, default: %{})
    field(:status, :string, default: "active")

    belongs_to(:project, StreamflixCore.Schemas.Project)
    has_many(:job_runs, StreamflixCore.Schemas.JobRun)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :project_id,
      :name,
      :schedule_type,
      :schedule_config,
      :action_type,
      :action_config,
      :status
    ])
    |> validate_required([:project_id, :name, :schedule_type, :action_type])
    |> validate_inclusion(:status, ~w(active inactive))
    |> validate_inclusion(:schedule_type, ~w(daily weekly monthly cron))
    |> validate_inclusion(:action_type, ~w(emit_event post_url))
    |> foreign_key_constraint(:project_id)
  end
end
