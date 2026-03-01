defmodule StreamflixCore.Schemas.JobRun do
  @moduledoc """
  JobRun schema: one execution of a job. History only; never deleted.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "job_runs" do
    field(:executed_at, :utc_datetime_usec)
    field(:status, :string)
    field(:result, :map)

    belongs_to(:job, StreamflixCore.Schemas.Job)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(job_run, attrs) do
    job_run
    |> cast(attrs, [:job_id, :executed_at, :status, :result])
    |> validate_required([:job_id, :executed_at, :status])
    |> validate_inclusion(:status, ~w(success failed))
    |> foreign_key_constraint(:job_id)
  end
end
