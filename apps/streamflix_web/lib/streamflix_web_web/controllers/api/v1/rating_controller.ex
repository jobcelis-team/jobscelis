defmodule StreamflixWebWeb.Api.V1.RatingController do
  use StreamflixWebWeb, :controller

  alias StreamflixCatalog

  action_fallback StreamflixWebWeb.FallbackController

  @doc """
  Rates content.
  """
  def rate(conn, %{"content_id" => content_id} = params) do
    user = conn.assigns.current_user
    profile_id = params["profile_id"]
    rating = params["rating"]

    # Validate rating
    rating_value = case rating do
      r when is_integer(r) and r >= 1 and r <= 5 -> r
      r when is_binary(r) -> String.to_integer(r)
      _ -> nil
    end

    if rating_value == nil or rating_value < 1 or rating_value > 5 do
      {:error, "Rating must be between 1 and 5"}
    else
      case StreamflixCatalog.rate_content(user.id, profile_id, content_id, rating_value) do
        {:ok, _} ->
          json(conn, %{
            success: true,
            content_id: content_id,
            rating: rating_value
          })

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Removes a rating from content.
  """
  def unrate(conn, %{"content_id" => content_id} = params) do
    user = conn.assigns.current_user
    profile_id = params["profile_id"]

    {:ok, _} = StreamflixCatalog.remove_rating(user.id, profile_id, content_id)
    send_resp(conn, :no_content, "")
  end
end
