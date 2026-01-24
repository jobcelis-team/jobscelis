defmodule StreamflixWebWeb.FallbackController do
  @moduledoc """
  Handles errors from controllers.
  """

  use StreamflixWebWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)

    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: errors})
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Not found"})
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Unauthorized"})
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "Forbidden"})
  end

  def call(conn, {:error, reason}) when is_binary(reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: reason})
  end

  def call(conn, {:error, reason}) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: "Internal server error", details: inspect(reason)})
  end
end
