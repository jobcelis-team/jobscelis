defmodule StreamflixWebWeb.Api.V1.PlatformProjectController do
  use StreamflixWebWeb, :controller

  alias StreamflixCore.Platform

  def show(conn, _params) do
    project = conn.assigns.current_project
    json(conn, %{
      id: project.id,
      name: project.name,
      status: project.status,
      settings: project.settings || %{}
    })
  end

  def update(conn, params) do
    project = conn.assigns.current_project
    attrs = Map.take(params, ["name", "settings"])
    attrs = Enum.reject(attrs, fn {_, v} -> is_nil(v) end) |> Map.new()
    case Platform.update_project(project, attrs) do
      {:ok, updated} -> json(conn, %{id: updated.id, name: updated.name, status: updated.status})
      {:error, changeset} -> conn |> put_status(422) |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)})
    end
  end

  def topics(conn, _params) do
    project = conn.assigns.current_project
    topics = Platform.list_topics_used(project.id)
    json(conn, %{topics: topics})
  end

  def token(conn, _params) do
    project = conn.assigns.current_project
    api_key = Platform.get_api_key_for_project(project.id)
    json(conn, %{
      prefix: if(api_key, do: api_key.prefix, else: nil),
      message: "Use Authorization: Bearer <your_key>. Regenerate from dashboard to get a new key."
    })
  end

  def regenerate_token(conn, _params) do
    project = conn.assigns.current_project
    case Platform.regenerate_api_key(project.id) do
      {:ok, _api_key, raw_key} ->
        json(conn, %{
          token: raw_key,
          message: "The previous token no longer works. Only this token is valid. Save it; it is only shown once."
        })
      {:error, _} ->
        send_resp(conn, 500, Jason.encode!(%{error: "Failed to regenerate token"}))
    end
  end
end
