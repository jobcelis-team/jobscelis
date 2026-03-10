defmodule StreamflixWebWeb.Api.V1.PlatformProjectController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixCore.Platform
  alias StreamflixWebWeb.Schemas

  tags(["Project"])
  security([%{"api_key" => []}])

  operation(:show,
    summary: "Get current project details",
    responses: [
      ok:
        {"Project details", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             id: %OpenApiSpex.Schema{type: :string},
             name: %OpenApiSpex.Schema{type: :string},
             status: %OpenApiSpex.Schema{type: :string},
             settings: %OpenApiSpex.Schema{type: :object}
           }
         }}
    ]
  )

  def show(conn, _params) do
    project = conn.assigns.current_project

    json(conn, %{
      id: project.id,
      name: project.name,
      status: project.status,
      settings: project.settings || %{},
      retention_policy: project.retention_policy || %{}
    })
  end

  operation(:update,
    summary: "Update project settings",
    request_body:
      {"Project attributes", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           name: %OpenApiSpex.Schema{type: :string},
           settings: %OpenApiSpex.Schema{type: :object}
         }
       }},
    responses: [
      ok:
        {"Project updated", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             id: %OpenApiSpex.Schema{type: :string},
             name: %OpenApiSpex.Schema{type: :string},
             status: %OpenApiSpex.Schema{type: :string}
           }
         }},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ErrorResponse}
    ]
  )

  def update(conn, params) do
    project = conn.assigns.current_project
    attrs = Map.take(params, ["name", "settings", "retention_policy"])
    attrs = Enum.reject(attrs, fn {_, v} -> is_nil(v) end) |> Map.new()

    case Platform.update_project(project, attrs) do
      {:ok, updated} ->
        json(conn, %{id: updated.id, name: updated.name, status: updated.status})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)})
    end
  end

  operation(:topics,
    summary: "List topics used in project",
    responses: [
      ok:
        {"Topics list", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             topics: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :string}}
           }
         }}
    ]
  )

  def topics(conn, _params) do
    project = conn.assigns.current_project
    topics = Platform.list_topics_used(project.id)
    json(conn, %{topics: topics})
  end

  operation(:token,
    summary: "Get API token info",
    responses: [
      ok:
        {"Token info", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             prefix: %OpenApiSpex.Schema{type: :string, nullable: true},
             message: %OpenApiSpex.Schema{type: :string}
           }
         }}
    ]
  )

  def token(conn, _params) do
    project = conn.assigns.current_project
    api_key = Platform.get_api_key_for_project(project.id)

    json(conn, %{
      prefix: if(api_key, do: api_key.prefix, else: nil),
      message: "Use Authorization: Bearer <your_key>. Regenerate from dashboard to get a new key."
    })
  end

  operation(:regenerate_token,
    summary: "Regenerate project API token",
    responses: [
      ok:
        {"New token generated", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             token: %OpenApiSpex.Schema{type: :string},
             message: %OpenApiSpex.Schema{type: :string}
           }
         }},
      internal_server_error: {"Regeneration failed", "application/json", Schemas.ErrorResponse}
    ]
  )

  def regenerate_token(conn, _params) do
    project = conn.assigns.current_project

    case Platform.regenerate_api_key(project.id) do
      {:ok, _api_key, raw_key} ->
        json(conn, %{
          token: raw_key,
          message:
            "The previous token no longer works. Only this token is valid. Save it; it is only shown once."
        })

      {:error, _} ->
        send_resp(conn, 500, Jason.encode!(%{error: "Failed to regenerate token"}))
    end
  end

  operation(:retention,
    summary: "Get project retention policy",
    responses: [
      ok:
        {"Retention policy", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             retention_days: %OpenApiSpex.Schema{type: :integer, nullable: true},
             retention_policy: %OpenApiSpex.Schema{type: :object}
           }
         }}
    ]
  )

  def retention(conn, _params) do
    project = conn.assigns.current_project

    json(conn, %{
      retention_days: project.retention_days,
      retention_policy: project.retention_policy || %{}
    })
  end

  operation(:update_retention,
    summary: "Update project retention policy",
    request_body:
      {"Retention policy", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           retention_policy: %OpenApiSpex.Schema{type: :object}
         }
       }},
    responses: [
      ok:
        {"Policy updated", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             retention_policy: %OpenApiSpex.Schema{type: :object}
           }
         }},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ErrorResponse}
    ]
  )

  def update_retention(conn, %{"retention_policy" => policy}) do
    project = conn.assigns.current_project

    case Platform.update_retention_policy(project, policy) do
      {:ok, updated} ->
        json(conn, %{retention_policy: updated.retention_policy || %{}})

      {:error, :invalid_policy} ->
        conn |> put_status(422) |> json(%{error: "Invalid retention policy"})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)})
    end
  end

  def update_retention(conn, _params) do
    conn |> put_status(422) |> json(%{error: "Missing retention_policy parameter"})
  end

  operation(:purge,
    summary: "Manually purge old data for a project",
    request_body:
      {"Purge params", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         required: [:type, :older_than],
         properties: %{
           type: %OpenApiSpex.Schema{
             type: :string,
             enum: ["events", "deliveries", "audit_logs", "dead_letters"]
           },
           older_than: %OpenApiSpex.Schema{type: :string, format: :date},
           topic: %OpenApiSpex.Schema{type: :string},
           status: %OpenApiSpex.Schema{type: :string}
         }
       }},
    responses: [
      ok:
        {"Purge result", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             type: %OpenApiSpex.Schema{type: :string},
             deleted_count: %OpenApiSpex.Schema{type: :integer},
             older_than: %OpenApiSpex.Schema{type: :string}
           }
         }},
      unprocessable_entity: {"Invalid params", "application/json", Schemas.ErrorResponse}
    ]
  )

  def purge(conn, params) do
    project = conn.assigns.current_project

    case Platform.manual_purge(project.id, params) do
      {:ok, result} ->
        json(conn, result)

      {:error, :invalid_type} ->
        conn
        |> put_status(422)
        |> json(%{
          error: "Invalid type. Must be one of: events, deliveries, audit_logs, dead_letters"
        })

      {:error, :invalid_date} ->
        conn
        |> put_status(422)
        |> json(%{error: "Invalid or missing older_than date. Use YYYY-MM-DD format"})
    end
  end

  operation(:preview_purge,
    summary: "Preview how many records would be purged",
    request_body:
      {"Purge preview params", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         required: [:type, :older_than],
         properties: %{
           type: %OpenApiSpex.Schema{
             type: :string,
             enum: ["events", "deliveries", "audit_logs", "dead_letters"]
           },
           older_than: %OpenApiSpex.Schema{type: :string, format: :date},
           topic: %OpenApiSpex.Schema{type: :string},
           status: %OpenApiSpex.Schema{type: :string}
         }
       }},
    responses: [
      ok:
        {"Preview result", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             type: %OpenApiSpex.Schema{type: :string},
             count: %OpenApiSpex.Schema{type: :integer},
             older_than: %OpenApiSpex.Schema{type: :string}
           }
         }},
      unprocessable_entity: {"Invalid params", "application/json", Schemas.ErrorResponse}
    ]
  )

  def preview_purge(conn, params) do
    project = conn.assigns.current_project

    case Platform.preview_purge(project.id, params) do
      {:ok, result} ->
        json(conn, result)

      {:error, :invalid_type} ->
        conn
        |> put_status(422)
        |> json(%{
          error: "Invalid type. Must be one of: events, deliveries, audit_logs, dead_letters"
        })

      {:error, :invalid_date} ->
        conn
        |> put_status(422)
        |> json(%{error: "Invalid or missing older_than date. Use YYYY-MM-DD format"})
    end
  end
end
