defmodule StreamflixCore.Platform.Pipelines do
  @moduledoc """
  Context for managing event pipelines.
  Pipelines define processing chains: filter → transform → delay → deliver.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.Pipeline

  @doc "Create a new pipeline for a project."
  def create_pipeline(project_id, attrs) do
    %Pipeline{}
    |> Pipeline.changeset(Map.put(attrs, "project_id", project_id))
    |> Repo.insert()
  end

  @doc "List all pipelines for a project."
  def list_pipelines(project_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Pipeline
    |> where([p], p.project_id == ^project_id)
    |> order_by([p], desc: p.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Get a pipeline by ID."
  def get_pipeline(id) do
    Repo.get(Pipeline, id)
  end

  @doc "Update a pipeline."
  def update_pipeline(%Pipeline{} = pipeline, attrs) do
    pipeline
    |> Pipeline.changeset(attrs)
    |> Repo.update()
  end

  @doc "Soft-delete a pipeline (set inactive)."
  def set_pipeline_inactive(%Pipeline{} = pipeline) do
    pipeline
    |> Pipeline.changeset(%{status: "inactive"})
    |> Repo.update()
  end

  @doc """
  Find active pipelines matching an event topic for a project.
  Uses the same wildcard matching as webhooks.
  """
  def matching_pipelines(project_id, topic) do
    Pipeline
    |> where([p], p.project_id == ^project_id and p.status == "active")
    |> Repo.all()
    |> Enum.filter(fn pipeline ->
      pipeline.topics == [] or
        Enum.any?(pipeline.topics, &topic_matches?(&1, topic))
    end)
  end

  defp topic_matches?(pattern, topic) do
    regex =
      pattern
      |> String.replace(".", "\\.")
      |> String.replace("*", "[^.]+")
      |> then(&("^" <> &1 <> "$"))
      |> Regex.compile!()

    Regex.match?(regex, topic)
  end

  @doc """
  Execute pipeline steps on a payload. Returns the transformed payload
  or {:filtered, reason} if the event should be skipped.
  """
  def execute_steps(steps, payload) do
    Enum.reduce_while(steps, {:ok, payload}, fn step, {:ok, current_payload} ->
      case execute_step(step, current_payload) do
        {:ok, new_payload} -> {:cont, {:ok, new_payload}}
        {:filtered, reason} -> {:halt, {:filtered, reason}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp execute_step(%{"type" => "filter"} = step, payload) do
    field = Map.get(step, "field")
    operator = Map.get(step, "operator", "eq")
    value = Map.get(step, "value")

    actual = get_in_payload(payload, field)

    matches? =
      case operator do
        "eq" -> actual == value
        "neq" -> actual != value
        "gt" -> is_number(actual) and actual > value
        "gte" -> is_number(actual) and actual >= value
        "lt" -> is_number(actual) and actual < value
        "lte" -> is_number(actual) and actual <= value
        "contains" -> is_binary(actual) and String.contains?(actual, to_string(value))
        "exists" -> not is_nil(actual)
        "not_exists" -> is_nil(actual)
        _ -> true
      end

    if matches? do
      {:ok, payload}
    else
      {:filtered, "filter condition not met: #{field} #{operator} #{inspect(value)}"}
    end
  end

  defp execute_step(%{"type" => "transform"} = step, payload) do
    StreamflixCore.Platform.Transformer.apply_transform(step, payload)
  end

  defp execute_step(%{"type" => "delay"} = _step, payload) do
    # Delay is handled at the delivery scheduling level, not here
    # We pass through the payload unchanged
    {:ok, payload}
  end

  defp execute_step(_unknown, payload), do: {:ok, payload}

  defp get_in_payload(payload, field) when is_binary(field) do
    keys = String.split(field, ".")

    Enum.reduce(keys, payload, fn key, acc ->
      case acc do
        %{} = map -> Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
        _ -> nil
      end
    end)
  rescue
    ArgumentError -> nil
  end

  defp get_in_payload(payload, _), do: payload
end
