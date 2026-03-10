defmodule StreamflixWebWeb.Api.V1.EmbedTokensController do
  @moduledoc """
  API controller for managing embed tokens.
  Authenticated via API key (project owners generate tokens for end-users).
  """
  use StreamflixWebWeb, :controller

  alias StreamflixCore.EmbedTokens

  action_fallback StreamflixWebWeb.FallbackController

  def index(conn, _params) do
    project = conn.assigns.current_project
    tokens = EmbedTokens.list_by_project(project.id)
    json(conn, %{data: Enum.map(tokens, &token_json/1)})
  end

  def create(conn, params) do
    project = conn.assigns.current_project

    attrs =
      params
      |> Map.take(["name", "scopes", "allowed_origins", "metadata", "expires_at"])
      |> parse_expires_at()

    case EmbedTokens.create(project.id, atomize_keys(attrs)) do
      {:ok, raw_token, token} ->
        conn
        |> put_status(:created)
        |> json(%{
          token: raw_token,
          data: token_json(token)
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case EmbedTokens.revoke(id) do
      {:ok, _token} -> json(conn, %{status: "revoked"})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "Not found"})
    end
  end

  defp token_json(token) do
    %{
      id: token.id,
      prefix: token.prefix,
      name: token.name,
      status: token.status,
      scopes: token.scopes,
      allowed_origins: token.allowed_origins,
      metadata: token.metadata,
      expires_at: token.expires_at,
      inserted_at: token.inserted_at
    }
  end

  defp parse_expires_at(%{"expires_at" => val} = attrs) when is_binary(val) do
    case DateTime.from_iso8601(val) do
      {:ok, dt, _} -> Map.put(attrs, "expires_at", DateTime.truncate(dt, :microsecond))
      _ -> Map.delete(attrs, "expires_at")
    end
  end

  defp parse_expires_at(attrs), do: attrs

  defp atomize_keys(map) do
    Map.new(map, fn {k, v} -> {String.to_existing_atom(k), v} end)
  rescue
    ArgumentError -> map
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
