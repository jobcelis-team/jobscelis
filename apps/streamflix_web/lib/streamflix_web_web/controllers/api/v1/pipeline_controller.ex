defmodule StreamflixWebWeb.Api.V1.PipelineController do
  @moduledoc """
  API controller for event pipelines.
  Pipelines define processing chains: filter → transform → delay → deliver.
  """
  use StreamflixWebWeb, :controller

  alias StreamflixCore.Platform

  def index(conn, _params) do
    project_id = conn.assigns[:project_id]
    pipelines = Platform.list_pipelines(project_id)

    json(conn, %{
      data:
        Enum.map(pipelines, fn p ->
          %{
            id: p.id,
            name: p.name,
            status: p.status,
            description: p.description,
            topics: p.topics,
            steps: p.steps,
            webhook_id: p.webhook_id,
            inserted_at: p.inserted_at
          }
        end)
    })
  end

  def create(conn, params) do
    project_id = conn.assigns[:project_id]

    case Platform.create_pipeline(project_id, params) do
      {:ok, pipeline} ->
        conn
        |> put_status(:created)
        |> json(%{
          data: %{
            id: pipeline.id,
            name: pipeline.name,
            status: pipeline.status,
            description: pipeline.description,
            topics: pipeline.topics,
            steps: pipeline.steps,
            webhook_id: pipeline.webhook_id,
            inserted_at: pipeline.inserted_at
          }
        })

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Validation failed", details: errors})
    end
  end

  def show(conn, %{"id" => id}) do
    case Platform.get_pipeline(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Pipeline not found"})

      pipeline ->
        json(conn, %{
          data: %{
            id: pipeline.id,
            name: pipeline.name,
            status: pipeline.status,
            description: pipeline.description,
            topics: pipeline.topics,
            steps: pipeline.steps,
            webhook_id: pipeline.webhook_id,
            inserted_at: pipeline.inserted_at
          }
        })
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Platform.get_pipeline(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Pipeline not found"})

      pipeline ->
        case Platform.update_pipeline(pipeline, params) do
          {:ok, updated} ->
            json(conn, %{
              data: %{
                id: updated.id,
                name: updated.name,
                status: updated.status,
                description: updated.description,
                topics: updated.topics,
                steps: updated.steps,
                webhook_id: updated.webhook_id,
                inserted_at: updated.inserted_at
              }
            })

          {:error, changeset} ->
            errors =
              Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Validation failed", details: errors})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Platform.get_pipeline(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Pipeline not found"})

      pipeline ->
        case Platform.set_pipeline_inactive(pipeline) do
          {:ok, _} -> send_resp(conn, :no_content, "")
          {:error, _} -> conn |> put_status(500) |> json(%{error: "Failed to delete pipeline"})
        end
    end
  end

  @doc "POST /api/v1/pipelines/:id/test — Test a pipeline with sample payload"
  def test(conn, %{"id" => id} = params) do
    case Platform.get_pipeline(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Pipeline not found"})

      pipeline ->
        payload = Map.get(params, "payload", %{})

        case Platform.execute_pipeline_steps(pipeline.steps, payload) do
          {:ok, transformed} ->
            json(conn, %{
              input: payload,
              output: transformed,
              steps_count: length(pipeline.steps),
              status: "passed"
            })

          {:filtered, reason} ->
            json(conn, %{
              input: payload,
              output: nil,
              steps_count: length(pipeline.steps),
              status: "filtered",
              reason: reason
            })

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Pipeline execution failed", reason: inspect(reason)})
        end
    end
  end
end
