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
    |> validate_post_url()
    |> validate_schedule()
    |> foreign_key_constraint(:project_id)
  end

  # A schedule that can never match would make the job silently never run
  defp validate_schedule(changeset) do
    cfg = get_field(changeset, :schedule_config) || %{}

    case get_field(changeset, :schedule_type) do
      "cron" ->
        expr = cfg["expr"] || cfg["expression"]

        case is_binary(expr) && Crontab.CronExpression.Parser.parse(expr) do
          {:ok, _} -> changeset
          _ -> add_error(changeset, :schedule_config, "invalid cron expression")
        end

      type when type in ~w(daily weekly monthly) ->
        changeset
        |> check_range(cfg, "hour", 0..23)
        |> check_range(cfg, "minute", 0..59)
        |> then(&if type == "weekly", do: check_range(&1, cfg, "day_of_week", 0..7), else: &1)
        |> then(&if type == "monthly", do: check_range(&1, cfg, "day_of_month", 1..31), else: &1)

      _ ->
        changeset
    end
  end

  defp check_range(changeset, cfg, key, range) do
    value =
      case cfg[key] do
        s when is_binary(s) -> String.to_integer(s)
        v -> v
      end

    if is_nil(value) or (is_integer(value) and value in range) do
      changeset
    else
      add_error(
        changeset,
        :schedule_config,
        "#{key} must be between #{range.first} and #{range.last}"
      )
    end
  rescue
    ArgumentError -> add_error(changeset, :schedule_config, "#{key} must be an integer")
  end

  # "Call URL" jobs: the target must be a public http(s) URL (SSRF guard)
  defp validate_post_url(changeset) do
    with "post_url" <- get_field(changeset, :action_type),
         %{} = config <- get_field(changeset, :action_config) || %{},
         true <- changed?(changeset, :action_config) or changed?(changeset, :action_type) do
      case StreamflixCore.Platform.UrlGuard.check(config["url"]) do
        :ok ->
          changeset

        {:error, reason} ->
          add_error(
            changeset,
            :action_config,
            "url " <> StreamflixCore.Platform.UrlGuard.message(reason)
          )
      end
    else
      _ -> changeset
    end
  end
end
