defmodule StreamflixWebWeb.Api.V1.SearchController do
  use StreamflixWebWeb, :controller

  alias StreamflixCatalog

  action_fallback StreamflixWebWeb.FallbackController

  @doc """
  Searches for content.
  """
  def search(conn, params) do
    query = params["q"] || ""
    type = params["type"]
    genre = params["genre"]
    page = String.to_integer(params["page"] || "1")
    per_page = String.to_integer(params["per_page"] || "20")

    opts = [
      type: type,
      genre: genre,
      page: page,
      per_page: per_page
    ] |> Enum.filter(fn {_, v} -> v != nil end)

    results = StreamflixCatalog.search(query, opts)

    json(conn, %{
      results: Enum.map(results, &content_json/1),
      page: page,
      per_page: per_page,
      query: query
    })
  end

  @doc """
  Returns autocomplete suggestions.
  """
  def autocomplete(conn, %{"q" => query}) do
    suggestions = StreamflixCatalog.autocomplete(query, limit: 10)

    json(conn, %{
      suggestions: suggestions
    })
  end

  def autocomplete(conn, _params) do
    json(conn, %{suggestions: []})
  end

  defp content_json(content) do
    %{
      id: content.id,
      title: content.title,
      type: content.type,
      poster_url: content.poster_url,
      year: content.release_year,
      rating: content.rating
    }
  end
end
